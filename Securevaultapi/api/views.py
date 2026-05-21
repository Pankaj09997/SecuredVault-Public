import base64
import json
import logging
import os
from datetime import timedelta
import random
from django.conf import settings
from django.contrib.auth import authenticate
from django.core.cache import cache
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.db import models, transaction
from django.http import FileResponse, HttpResponse, HttpResponseForbidden
from django.shortcuts import get_object_or_404
from django.utils import timezone
import secrets
from rest_framework import serializers, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
import requests

from api.middleware.location_tracking import SecurityMiddleware
from api.models import (
    DeviceInfo, DeviceVerification, EncryptedFile, EncryptedImage,
    FileAccessLog, FileTransfer, ImageAccessLog, LoginAttempt, MyUser, Peer, Room,
    SecurityNotification, SharedFileResource, SuspiciousActivityLog,
    UserLocation,
)
from api. serializers import (
    ForgotPasswordSerializer, FileTransferInitSerializer,
    FileTransferSerializer, PeerSerializer, ResendForgotOtpSerializer,
    ResendOtpCodeSerializer, ResetOtpVerifySerializer, ResetPasswordSerializer,
    RoomCreateSerializer, RoomJoinSerializer, RoomSerializer,
    UserLoginSerializer, UserRegistrationSerializer, VerifyOtpSerializer,ChangePasswordSerializer,UpdateProfileSerializer,GetUserProfileSerializer
)
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken
from api.utils import (
    decrypt_file, decrypt_image, encrypt_file, encrypt_image,
    generate_device_fingerprint, generate_encrypted_file_name,
    generate_encrypted_image_path, get_client_ip,
)
from api.throttles import (
    SharedResourceViewThrottle, LoginThrottle, OTPThrottle, BurstThrottle
)
from api.security_config import NOTIFICATION_SETTINGS, THREAT_DETECTION_CONFIG
from api.security_actions import apply_security_rule, clear_expired_user_block
import ipaddress


logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def get_token_for_user(user):
    refresh = RefreshToken.for_user(user)
    return {'refresh': str(refresh), 'access': str(refresh.access_token)}


def _device_and_location(request, user):
    """Return (DeviceInfo | None, UserLocation | None) for the current request."""
    fp = generate_device_fingerprint(request)
    ip = get_client_ip(request)
    device = DeviceInfo.objects.filter(user=user, device_id=fp).first()
    location = UserLocation.objects.filter(user=user, ip_address=ip).first()
    return device, location

    
        
def _log_file_access(encrypted_file, user, action, request):
    device, location = _device_and_location(request, user)
    FileAccessLog.objects.create(
        file=encrypted_file,
        user=user,
        action=action,
        ip_address=get_client_ip(request),
        device=device,
        location=location,
        country=location.country if location else None,
        region=location.region if location else None,
        city=location.city if location else None,
        latitude=location.latitude if location else None,
        longitude=location.longitude if location else None,
        isp=location.isp if location else None,
        timezone=location.timezone if location else None,
    )


def _log_image_access(encrypted_image, user, action, request):
    device, location = _device_and_location(request, user)
    ImageAccessLog.objects.create(
        image=encrypted_image,
        user=user,
        action=action,
        ip_address=get_client_ip(request),
        device=device,
        location=location,
        country=location.country if location else None,
        region=location.region if location else None,
        city=location.city if location else None,
        latitude=location.latitude if location else None,
        longitude=location.longitude if location else None,
        isp=location.isp if location else None,
        timezone=location.timezone if location else None,
    )


def _unauthorized_access_log(user, activity_type, detail_key, detail_val, request):
    SuspiciousActivityLog.objects.create(
        user=user,
        activity_type=activity_type,
        threat_level='HIGH',
        ip_address=get_client_ip(request),
        details={detail_key: detail_val},
        action_taken='blocked',
    )


# ---------------------------------------------------------------------------
# Async helpers (import canonical tasks from api.tasks)
# ---------------------------------------------------------------------------

from api.tasks import send_async_email as _send_async_email_task, update_geolocation_async


def send_security_notification_from_view(user_id, notification_type, context):
    """Build and dispatch a security notification email with cooldown guard.
    
    This is the views-specific version that uses the HTML email templates
    defined in _build_email(). It delegates actual sending to api.tasks.send_async_email.
    """
    try:
        user = MyUser.objects.get(id=user_id)
        cooldown_key = f"notify_cooldown_{user.id}_{notification_type}"
        if cache.get(cooldown_key):
            return

        subject, html_body, plain_body = _build_email(notification_type, context)

        email_kwargs = {
            'subject': subject,
            'message': plain_body,
            'from_email': settings.DEFAULT_FROM_EMAIL,
            'recipient_list': [user.email],
            'html_body': html_body,
            'plain_body': plain_body,
        }
        if getattr(settings, 'SEND_EMAILS_ASYNC', True):
            _send_async_email_task.delay(**email_kwargs)
        else:
            _send_async_email_task(**email_kwargs)

        SecurityNotification.objects.create(
            user=user,
            notification_type=notification_type,
            title=subject,
            message=plain_body,
            email_sent=True,
            email_sent_at=timezone.now(),
        )

        cooldown = NOTIFICATION_SETTINGS.get('email_cooldown_minutes', 15) * 60
        cache.set(cooldown_key, True, cooldown)
    except Exception as exc:
        logger.error("Failed to send security notification to user %s: %s", user_id, exc)


# ---------------------------------------------------------------------------
# Professional HTML email builder
# ---------------------------------------------------------------------------

# Shared colour palette — matched to SecuredVault logo
_PALETTE = {
    'brand':       '#56CCF2',
    'brand_dark':  '#7B5EA7',
    'navy':        '#0D1B2A',
    'navy_light':  '#1B2D45',
    'accent':      '#A78BFA',
    'success':     '#34D399',
    'warning':     '#FBBF24',
    'danger':      '#F87171',
    'critical':    '#EF4444',
    'text':        '#E2E8F0',
    'muted':       '#94A3B8',
    'bg':          '#0F172A',
    'card':        '#1E293B',
    'border':      '#334155',
}

_THREAT_META = {
    'LOW':      {'color': _PALETTE['success'],  'label': 'Low',      'pct': '20%'},
    'MEDIUM':   {'color': _PALETTE['warning'],  'label': 'Medium',   'pct': '50%'},
    'HIGH':     {'color': _PALETTE['danger'],   'label': 'High',     'pct': '75%'},
    'CRITICAL': {'color': _PALETTE['critical'], 'label': 'Critical', 'pct': '100%'},
}


def _email_shell(title: str, preheader: str, body_html: str, threat_level: str = 'LOW') -> str:
    """
    Wrap *body_html* in a full responsive email shell.
    Every template calls this — changing the shell updates all emails at once.
    """
    tm = _THREAT_META.get(threat_level, _THREAT_META['LOW'])
    year = timezone.now().year
    support = settings.DEFAULT_FROM_EMAIL
    base_url = getattr(settings, 'BASE_URL', '')
    logo_url = f"{base_url}/static/logo.png"

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="x-apple-disable-message-reformatting">
<title>{title}</title>
<!--[if mso]>
<noscript><xml><o:OfficeDocumentSettings>
<o:PixelsPerInch>96</o:PixelsPerInch>
</o:OfficeDocumentSettings></xml></noscript>
<![endif]-->
<style>
  *,*::before,*::after{{box-sizing:border-box;margin:0;padding:0}}
  body{{font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;
        background:{_PALETTE['bg']};color:{_PALETTE['text']};line-height:1.6;
        -webkit-font-smoothing:antialiased;margin:0;padding:0}}
  a{{color:{_PALETTE['brand']};text-decoration:none}}
  img{{border:0;display:block;max-width:100%}}
  .wrapper{{width:100%;background:{_PALETTE['bg']};padding:32px 16px}}
  .container{{max-width:600px;margin:0 auto}}
  /* ── header ── */
  .hdr{{background:linear-gradient(135deg,{_PALETTE['navy']},{_PALETTE['navy_light']});
        border-radius:16px 16px 0 0;padding:32px 40px;text-align:center;
        border:1px solid {_PALETTE['border']};border-bottom:none}}
  .hdr-icon{{font-size:36px;margin-bottom:8px}}
  .hdr-title{{background:linear-gradient(135deg,{_PALETTE['brand']},{_PALETTE['accent']});
              -webkit-background-clip:text;-webkit-text-fill-color:transparent;
              background-clip:text;font-size:22px;font-weight:800;letter-spacing:-0.3px}}
  .hdr-sub{{color:{_PALETTE['muted']};font-size:13px;margin-top:6px}}
  /* ── card ── */
  .card{{background:{_PALETTE['card']};padding:32px 40px;
         border:1px solid {_PALETTE['border']};border-top:none}}
  .card-title{{font-size:18px;font-weight:700;color:{_PALETTE['text']};margin-bottom:6px}}
  .card-lead{{font-size:14px;color:{_PALETTE['muted']};margin-bottom:24px}}
  /* ── threat badge ── */
  .threat-row{{display:flex;align-items:center;gap:10px;
               background:{_PALETTE['navy']};border-radius:10px;
               padding:12px 16px;margin-bottom:24px;
               border-left:4px solid {tm['color']};border:1px solid {_PALETTE['border']};
               border-left:4px solid {tm['color']}}}
  .threat-dot{{width:10px;height:10px;border-radius:50%;
               background:{tm['color']};flex-shrink:0}}
  .threat-label{{font-size:13px;font-weight:600;color:{tm['color']}}}
  .threat-text{{font-size:13px;color:{_PALETTE['muted']}}}
  /* ── detail table ── */
  .detail-table{{width:100%;border-collapse:collapse;margin-bottom:24px}}
  .detail-table td{{padding:10px 14px;font-size:13px;
                    border-bottom:1px solid {_PALETTE['border']}}}
  .detail-table td:first-child{{color:{_PALETTE['muted']};font-weight:600;
                                 white-space:nowrap;width:38%}}
  .detail-table td:last-child{{color:{_PALETTE['text']};font-weight:500}}
  .detail-table tr:last-child td{{border-bottom:none}}
  /* ── CTA button ── */
  .btn{{display:inline-block;padding:13px 28px;
        background:linear-gradient(135deg,{_PALETTE['brand']},{_PALETTE['accent']});
        color:{_PALETTE['navy']}!important;font-size:14px;font-weight:700;
        border-radius:8px;text-align:center;letter-spacing:0.2px;
        mso-padding-alt:0;text-decoration:none}}
  .btn-danger{{background:linear-gradient(135deg,{_PALETTE['danger']},{_PALETTE['critical']});color:#fff!important}}
  .btn-row{{text-align:center;margin:28px 0 8px}}
  /* ── divider ── */
  .divider{{border:none;border-top:1px solid {_PALETTE['border']};margin:24px 0}}
  /* ── notice box ── */
  .notice{{background:rgba(251,191,36,0.08);border-radius:8px;padding:14px 18px;
           font-size:13px;color:{_PALETTE['warning']};border-left:4px solid {_PALETTE['warning']};
           margin-bottom:24px}}
  /* ── footer ── */
  .ftr{{background:{_PALETTE['navy']};border-radius:0 0 16px 16px;padding:20px 40px;
        text-align:center;border:1px solid {_PALETTE['border']};border-top:none}}
  .ftr p{{font-size:12px;color:{_PALETTE['muted']};margin-bottom:4px}}
  .ftr a{{color:{_PALETTE['brand']};font-weight:600}}
  /* ── responsive ── */
  @media(max-width:600px){{
    .card,.hdr,.ftr{{padding:24px 20px}}
    .detail-table td:first-child{{width:auto}}
  }}
</style>
</head>
<body>
<div class="wrapper">
  <div class="container">

    <!-- header -->
    <div class="hdr">
      <div class="hdr-icon">🔒</div>
      <div class="hdr-title">SecuredVault</div>
      <div class="hdr-sub">{preheader}</div>
    </div>

    <!-- body card -->
    <div class="card">
      <!-- threat level indicator -->
      <div class="threat-row">
        <div class="threat-dot"></div>
        <span class="threat-label">Threat level: {tm['label']}</span>
        <span class="threat-text">— {title}</span>
      </div>

      {body_html}
    </div>

    <!-- footer -->
    <div class="ftr">
      <p>You received this because security alerts are enabled on your account.</p>
      <p>Questions? <a href="mailto:{support}">{support}</a></p>
      <p style="margin-top:8px;color:#475569">&copy; {year} SecuredVault. All rights reserved.</p>
    </div>

  </div>
</div>
</body>
</html>"""


def _detail_row(label: str, value: str) -> str:
    return f"<tr><td>{label}</td><td>{value}</td></tr>"


def _btn(text: str, url: str, danger: bool = False) -> str:
    cls = "btn btn-danger" if danger else "btn"
    return f'<div class="btn-row"><a href="{url}" class="{cls}">{text}</a></div>'


def _build_email(notification_type: str, context: dict) -> tuple[str, str, str]:
    """
    Return (subject, html_body, plain_body) for *notification_type*.
    Add new notification types by adding an entry to *_TEMPLATES* below.
    """
    base_url = getattr(settings, 'BASE_URL', '')
    security_url = f"{base_url}/security"
    support_email = settings.DEFAULT_FROM_EMAIL
    now_str = context.get('time', timezone.now().strftime('%Y-%m-%d %H:%M UTC'))

    # ── per-type configuration ─────────────────────────────────────────────
    if notification_type == 'new_device':
        threat = 'MEDIUM'
        subject = 'New device sign-in detected — SecuredVault'
        preheader = 'A new device accessed your vault.'
        rows = (
            _detail_row('Device', context.get('device', 'Unknown')) +
            _detail_row('Location', context.get('location', 'Unknown')) +
            _detail_row('IP address', context.get('ip', 'Unknown')) +
            _detail_row('Time', now_str)
        )
        verify_url = context.get('verify_url', security_url)
        body = f"""
          <p class="card-title">New device sign-in</p>
          <p class="card-lead">
            We noticed a sign-in from a device we have not seen before.
            If this was you, verify the device below. If not, secure your account immediately.
          </p>
          <table class="detail-table">{rows}</table>
          {_btn('Verify this device', verify_url)}
          <hr class="divider">
          <div class="notice">
            Not you? <a href="{security_url}">Lock your account</a> and change your password right away.
          </div>"""
        plain = (
            f"New device sign-in detected.\n\n"
            f"Device: {context.get('device','Unknown')}\n"
            f"Location: {context.get('location','Unknown')}\n"
            f"IP: {context.get('ip','Unknown')}\n"
            f"Time: {now_str}\n\n"
            f"Verify: {verify_url}\n"
            f"Not you? Visit {security_url} to lock your account."
        )

    elif notification_type == 'impossible_travel':
        threat = 'CRITICAL'
        subject = 'Impossible travel detected — account locked'
        preheader = 'Your account has been temporarily locked.'
        blocked_until = context.get(
            'blocked_until',
            (timezone.now() + timedelta(hours=2)).strftime('%Y-%m-%d %H:%M UTC'),
        )
        rows = (
            _detail_row('From', context.get('from_location', 'Unknown')) +
            _detail_row('To', context.get('to_location', 'Unknown')) +
            _detail_row('Distance', f"{round(context.get('distance', 0), 1)} km") +
            _detail_row('Time elapsed', f"{round(context.get('time_elapsed', 0), 1)} min") +
            _detail_row('IP address', context.get('ip', 'Unknown')) +
            _detail_row('Locked until', str(blocked_until))
        )
        body = f"""
          <p class="card-title">Impossible travel detected</p>
          <p class="card-lead">
            Your account was accessed from two locations that are physically impossible
            to travel between in the recorded time. Your account has been locked as a precaution.
          </p>
          <table class="detail-table">{rows}</table>
          {_btn('Appeal & unlock account', security_url, danger=True)}
          <hr class="divider">
          <div class="notice">
            If this was a VPN or proxy, contact
            <a href="mailto:{support_email}">{support_email}</a> to restore access.
          </div>"""
        plain = (
            f"CRITICAL: Impossible travel detected. Account locked.\n\n"
            f"From: {context.get('from_location','?')}\n"
            f"To: {context.get('to_location','?')}\n"
            f"Distance: {round(context.get('distance',0),1)} km\n"
            f"Time elapsed: {round(context.get('time_elapsed',0),1)} min\n"
            f"IP: {context.get('ip','?')}\n"
            f"Locked until: {blocked_until}\n\n"
            f"Appeal at {security_url}"
        )

    elif notification_type == 'rapid_location_change':
        threat = 'HIGH'
        subject = 'Rapid location change detected — SecuredVault'
        preheader = 'Unusual location activity on your account.'
        rows = (
            _detail_row('From', context.get('from_location', 'Unknown')) +
            _detail_row('To', context.get('to_location', 'Unknown')) +
            _detail_row('Distance', f"{round(context.get('distance', 0), 1)} km") +
            _detail_row('Time elapsed', f"{round(context.get('time_elapsed', 0), 1)} min") +
            _detail_row('IP address', context.get('ip', 'Unknown')) +
            _detail_row('Time', now_str)
        )
        body = f"""
          <p class="card-title">Rapid location change</p>
          <p class="card-lead">
            Your account was accessed from two very different locations within a short time.
            Please confirm this was you.
          </p>
          <table class="detail-table">{rows}</table>
          {_btn('Review security settings', security_url)}
          <hr class="divider">
          <div class="notice">
            If this was not you, change your password immediately and enable two-factor authentication.
          </div>"""
        plain = (
            f"Rapid location change detected.\n\n"
            f"From: {context.get('from_location','?')}\n"
            f"To: {context.get('to_location','?')}\n"
            f"Distance: {round(context.get('distance',0),1)} km\n"
            f"Time elapsed: {round(context.get('time_elapsed',0),1)} min\n"
            f"IP: {context.get('ip','?')}\n"
            f"Time: {now_str}\n\n"
            f"Review: {security_url}"
        )

    elif notification_type == 'tampering_detected':
        threat = 'CRITICAL'
        subject = 'Data integrity alert — tampering detected'
        preheader = 'A file in your vault failed its integrity check.'
        rows = (
            _detail_row('File', context.get('encrypted_name', 'Unknown')) +
            _detail_row('Object type', context.get('object_type', 'Unknown')) +
            _detail_row('Reason', context.get('reason', 'GCM tag mismatch')) +
            _detail_row('IP address', context.get('ip', 'Unknown')) +
            _detail_row('Time', now_str)
        )
        body = f"""
          <p class="card-title">Data tampering detected</p>
          <p class="card-lead">
            A file stored in your SecuredVault failed its cryptographic integrity check.
            This may indicate an attempt to tamper with your data or a storage corruption event.
            Please contact support immediately.
          </p>
          <table class="detail-table">{rows}</table>
          {_btn('Contact support', f'mailto:{support_email}', danger=True)}
          <hr class="divider">
          <div class="notice">
            Your file has been quarantined. No data has been served to any user.
          </div>"""
        plain = (
            f"CRITICAL: Data tampering detected.\n\n"
            f"File: {context.get('encrypted_name','?')}\n"
            f"Reason: {context.get('reason','?')}\n"
            f"IP: {context.get('ip','?')}\n"
            f"Time: {now_str}\n\n"
            f"Contact support: {support_email}"
        )

    elif notification_type == 'file_access':
        threat = 'LOW'
        subject = f"File {context.get('action','access').lower()} activity — SecuredVault"
        preheader = f"Your file was {context.get('action','accessed').lower()}."
        rows = (
            _detail_row('Action', context.get('action', 'Unknown')) +
            _detail_row('File', context.get('file_name', 'Unknown')) +
            _detail_row('Location', context.get('location', 'Unknown')) +
            _detail_row('IP address', context.get('ip', 'Unknown')) +
            _detail_row('Time', now_str)
        )
        body = f"""
          <p class="card-title">File activity recorded</p>
          <p class="card-lead">The following activity was logged on your vault.</p>
          <table class="detail-table">{rows}</table>
          {_btn('View audit log', security_url)}"""
        plain = (
            f"File activity: {context.get('action','?')}\n"
            f"File: {context.get('file_name','?')}\n"
            f"Location: {context.get('location','?')}\n"
            f"IP: {context.get('ip','?')}\n"
            f"Time: {now_str}"
        )

    elif notification_type == 'account_locked':
        threat = 'HIGH'
        subject = 'Your SecuredVault account has been locked'
        preheader = 'Too many failed login attempts.'
        rows = (
            _detail_row('Reason', context.get('reason', 'Too many failed attempts')) +
            _detail_row('IP address', context.get('ip', 'Unknown')) +
            _detail_row('Time', now_str)
        )
        body = f"""
          <p class="card-title">Account locked</p>
          <p class="card-lead">
            Your account was locked after multiple failed sign-in attempts.
            It will unlock automatically after 30 minutes.
          </p>
          <table class="detail-table">{rows}</table>
          {_btn('Unlock my account', security_url)}
          <hr class="divider">
          <div class="notice">
            If this was not you, your password may be compromised.
            Reset it immediately after unlocking.
          </div>"""
        plain = (
            f"Account locked.\n"
            f"Reason: {context.get('reason','?')}\n"
            f"IP: {context.get('ip','?')}\n"
            f"Time: {now_str}\n\n"
            f"Unlock: {security_url}"
        )

    elif notification_type == 'password_change_otp':
        threat = 'LOW'
        subject = 'OTP for Password Change — SecuredVault'
        preheader = 'Your One-Time Password for changing your password.'
        otp = context.get('otp', '')
        body = f"""
          <p class="card-title">Password Change OTP</p>
          <p class="card-lead">
            You requested to change your password. Please use the following OTP to complete the process.
          </p>
          <div style="text-align: center; font-size: 24px; letter-spacing: 2px; margin: 20px 0;"><b>{otp}</b></div>
          <hr class="divider">
          <div class="notice">
            If you did not request this, please secure your account immediately.
          </div>"""
        plain = (
            f"Password Change OTP: {otp}\n\n"
            f"If you did not request this, please secure your account."
        )

    elif notification_type == 'password_changed':
        threat = 'MEDIUM'
        subject = 'Your password has been changed — SecuredVault'
        preheader = 'Your SecuredVault account password was updated.'
        rows = (
            _detail_row('Device', context.get('device', 'Unknown')) +
            _detail_row('IP address', context.get('ip', 'Unknown')) +
            _detail_row('Time', now_str)
        )
        body = f"""
          <p class="card-title">Password Changed</p>
          <p class="card-lead">
            Your account password was successfully changed. All other active sessions have been terminated.
          </p>
          <table class="detail-table">{rows}</table>
          <hr class="divider">
          <div class="notice">
            If you did not perform this action, contact support immediately.
          </div>"""
        plain = (
            f"Your password has been changed.\n\n"
            f"Device: {context.get('device', 'Unknown')}\n"
            f"IP: {context.get('ip', 'Unknown')}\n"
            f"Time: {now_str}\n\n"
            f"If you did not do this, contact support immediately."
        )

    else:
        # Generic fallback
        threat = 'MEDIUM'
        subject = 'Security alert — SecuredVault'
        preheader = 'Suspicious activity was detected on your account.'
        body = f"""
          <p class="card-title">Security alert</p>
          <p class="card-lead">
            Suspicious activity was detected on your SecuredVault account.
            Please review your security settings.
          </p>
          {_btn('Review security settings', security_url)}"""
        plain = (
            f"Security alert on your SecuredVault account.\n"
            f"Review your settings: {security_url}"
        )

    html_body = _email_shell(subject, preheader, body, threat)
    return subject, html_body, plain


# ---------------------------------------------------------------------------
# Auth views
# ---------------------------------------------------------------------------

class UserRegistrationView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [LoginThrottle]

    def post(self, request):
        serializer = UserRegistrationSerializer(data=request.data)
        try:
            serializer.is_valid(raise_exception=True)
            result = serializer.create(validated_data=serializer.validated_data)
            return Response({
                "message": "OTP sent to your email. Please verify to complete registration.",
                "email": result['email'],
            }, status=status.HTTP_200_OK)
        except serializers.ValidationError as exc:
            return Response({"errors": exc.detail}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as exc:
            logger.error("Registration error: %s", exc)
            return Response({"error": "Internal server error"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class UserLoginView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [LoginThrottle]

    def post(self, request):
        serializer = UserLoginSerializer(data=request.data)
        try:
            serializer.is_valid(raise_exception=True)
            user = authenticate(
                email=serializer.validated_data['email'].lower(),
                password=serializer.validated_data['password'],
            )
            if user is None:
                email_attempted = serializer.validated_data['email'].lower()
                existing_user = MyUser.objects.filter(email=email_attempted).first()
                if existing_user:
                    clear_expired_user_block(existing_user)
                    if existing_user.is_temporarily_blocked_active() or existing_user.is_account_locked():
                        LoginAttempt.objects.create(
                            user=existing_user,
                            email_attempted=email_attempted,
                            ip_address=get_client_ip(request),
                            status='blocked',
                            failure_reason=existing_user.blocked_reason or 'Account blocked',
                            is_suspicious=True,
                        )
                        return Response(
                            {"msg": f"Account temporarily blocked: {existing_user.blocked_reason}"},
                            status=status.HTTP_403_FORBIDDEN,
                        )

                    LoginAttempt.objects.create(
                        user=existing_user,
                        email_attempted=email_attempted,
                        ip_address=get_client_ip(request),
                        status='failed',
                        failure_reason='Invalid credentials',
                        is_suspicious=True,
                    )
                    failed_config = THREAT_DETECTION_CONFIG.get('FAILED_LOGIN_ATTEMPTS', {})
                    window_start = timezone.now() - timedelta(
                        minutes=failed_config.get('time_window_minutes', 15)
                    )
                    failed_count = LoginAttempt.objects.filter(
                        user=existing_user,
                        status='failed',
                        timestamp__gte=window_start,
                    ).count()
                    existing_user.failed_login_attempts = failed_count
                    existing_user.save(update_fields=['failed_login_attempts'])

                    if failed_count >= failed_config.get('max_attempts', 5):
                        apply_security_rule(
                            user=existing_user,
                            rule_name='FAILED_LOGIN_ATTEMPTS',
                            activity_type='multiple_failed_login',
                            ip_address=get_client_ip(request),
                            details={
                                'email_attempted': email_attempted,
                                'failed_attempts': failed_count,
                                'time_window_minutes': failed_config.get(
                                    'time_window_minutes',
                                    15,
                                ),
                            },
                            reason='Multiple failed login attempts detected',
                        )
                else:
                    LoginAttempt.objects.create(
                        email_attempted=email_attempted,
                        ip_address=get_client_ip(request),
                        status='failed',
                        failure_reason='User does not exist',
                        is_suspicious=True
                    )
                return Response({"msg": "Invalid credentials"}, status=status.HTTP_400_BAD_REQUEST)

            if not user.is_verified:
                return Response({"msg": "Please verify your account first"}, status=status.HTTP_403_FORBIDDEN)

            clear_expired_user_block(user)
            if user.is_temporarily_blocked_active() or user.is_account_locked():
                return Response(
                    {"msg": f"Account temporarily blocked: {user.blocked_reason}"},
                    status=status.HTTP_403_FORBIDDEN,
                )

            if user.failed_login_attempts:
                user.failed_login_attempts = 0
                user.save(update_fields=['failed_login_attempts'])

            fp = generate_device_fingerprint(request)
            ip = get_client_ip(request)
            device, created = DeviceInfo.objects.get_or_create(
                user=user,
                device_id=fp,
                defaults={
                    'user_agent': request.META.get('HTTP_USER_AGENT', ''),
                    'browser_info': request.META.get('HTTP_SEC_CH_UA', ''),
                    'last_used': timezone.now(),
                },
            )
            if created:
                sec = SecurityMiddleware(lambda r: None)
                geo = sec._get_geolocation_data(ip)
                loc_str = f"{geo['city']}, {geo['country']}" if geo['city'] != 'Unknown' else 'Unknown'
                verification = DeviceVerification.objects.create(user=user, device=device)
                verify_url = f"{settings.BASE_URL}/api/verify-device/{verification.token}/"
                apply_security_rule(
                    user=user,
                    rule_name='NEW_DEVICE_LOGIN',
                    activity_type='new_device',
                    ip_address=ip,
                    device=device,
                    details={
                        'device': device.user_agent,
                        'location': loc_str,
                        'verify_url': verify_url,
                    },
                )
                if THREAT_DETECTION_CONFIG.get('NEW_DEVICE_LOGIN', {}).get('require_verification', False):
                    return Response(
                        {
                            "msg": "New device detected. Please verify this device before logging in.",
                            "requires_device_verification": True,
                        },
                        status=status.HTTP_403_FORBIDDEN,
                    )
            elif THREAT_DETECTION_CONFIG.get('NEW_DEVICE_LOGIN', {}).get(
                'require_verification',
                False,
            ) and not device.is_verified:
                verification = DeviceVerification.objects.filter(
                    user=user,
                    device=device,
                    is_verified=False,
                    expires_at__gt=timezone.now(),
                ).order_by('-created_at').first()
                if verification is None:
                    verification = DeviceVerification.objects.create(user=user, device=device)
                apply_security_rule(
                    user=user,
                    rule_name='NEW_DEVICE_LOGIN',
                    activity_type='new_device',
                    ip_address=ip,
                    device=device,
                    details={
                        'device': device.user_agent,
                        'verify_url': f"{settings.BASE_URL}/api/verify-device/{verification.token}/",
                    },
                )
                return Response(
                    {
                        "msg": "Please verify this device before logging in.",
                        "requires_device_verification": True,
                    },
                    status=status.HTTP_403_FORBIDDEN,
                )

            sec = SecurityMiddleware(lambda r: None)
            geo = sec._get_geolocation_data(ip)
            location, _ = UserLocation.objects.update_or_create(
                user=user,
                ip_address=ip,
                defaults={
                    'country': geo['country'],
                    'region': geo['region'],
                    'city': geo['city'],
                    'latitude': geo['latitude'],
                    'longitude': geo['longitude'],
                    'isp': geo['isp'],
                    'timezone': geo['timezone'],
                },
            )
            sec._detect_rapid_location_change(user, location)
            clear_expired_user_block(user)
            if user.is_temporarily_blocked_active() or user.is_account_locked():
                return Response(
                    {"msg": f"Account temporarily blocked: {user.blocked_reason}"},
                    status=status.HTTP_403_FORBIDDEN,
                )

            LoginAttempt.objects.create(
                user=user,
                email_attempted=user.email,
                ip_address=ip,
                location=location,
                device=device,
                status='success',
                user_agent=request.META.get('HTTP_USER_AGENT', ''),
            )
            device.login_count += 1
            device.last_login_location = location
            device.save(update_fields=['login_count', 'last_login_location', 'last_used'])
            user.current_device = device
            user.last_login_time = timezone.now()
            user.last_login_location = {
                'ip_address': ip,
                'city': location.city,
                'country': location.country,
                'region': location.region,
            }
            user.save(update_fields=[
                'current_device',
                'last_login_time',
                'last_login_location',
            ])
            update_geolocation_async.delay(user.id, ip)

            token = get_token_for_user(user)
            return Response({
                "token": token,
                "msg": "Login successful",
                "email": user.email,
                "imageurl": user.image.url if user.image else None,
            }, status=status.HTTP_200_OK)
        except serializers.ValidationError as exc:
            return Response({"errors": exc.detail}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as exc:
            logger.error("Login error: %s", exc)
            return Response({"error": f"Internal server error ${exc}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class VerifyOtpView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [OTPThrottle]

    def post(self, request):
        serializer = VerifyOtpSerializer(data=request.data)
        try:
            serializer.is_valid(raise_exception=True)
            user = serializer.save()
            token = get_token_for_user(user)
            return Response({
                "token": token,
                "message": "Account verified successfully",
                "user": {
                    "email": user.email,
                    "name": user.name,
                    "image": user.image.url if user.image else None,
                },
            }, status=status.HTTP_201_CREATED)
        except serializers.ValidationError as exc:
            return Response({"errors": exc.detail}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as exc:
            logger.error("OTP verification error: %s", exc)
            return Response({"error": "Internal server error"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DeviceVerificationView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, token):
        from api.email_templates import device_verification_success_html, device_verification_error_html
        try:
            v = DeviceVerification.objects.select_related('user', 'device').get(token=token)
            if v.expires_at < timezone.now():
                return HttpResponse(
                    device_verification_error_html(
                        "This verification link has expired. Please log in again from your app to receive a new one.",
                        is_expired=True,
                    ),
                    content_type='text/html',
                    status=410,
                )
            if v.is_verified:
                return HttpResponse(
                    device_verification_error_html(
                        "This device has already been verified. You can close this page and log in from the app.",
                    ),
                    content_type='text/html',
                    status=400,
                )

            v.is_verified = True
            v.device.is_verified = True
            v.device.save(update_fields=['is_verified'])
            v.save(update_fields=['is_verified'])

            SuspiciousActivityLog.objects.create(
                user=v.user,
                activity_type='login',
                threat_level='LOW',
                ip_address=get_client_ip(request),
                device=v.device,
                details={'action': 'device verified via email'},
                action_taken='verified',
            )
            return HttpResponse(
                device_verification_success_html(),
                content_type='text/html',
                status=200,
            )
        except DeviceVerification.DoesNotExist:
            return HttpResponse(
                device_verification_error_html(
                    "This verification link is invalid or has already been used.",
                ),
                content_type='text/html',
                status=404,
            )
        except Exception as exc:
            logger.error("Device verification error: %s", exc)
            return HttpResponse(
                device_verification_error_html(
                    "An unexpected error occurred. Please try again later or contact support.",
                ),
                content_type='text/html',
                status=500,
            )


class ForgotPasswordView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [OTPThrottle]

    def post(self, request):
        serializer = ForgotPasswordSerializer(data=request.data)
        try:
            serializer.is_valid(raise_exception=True)
            serializer.save()
            return Response({"msg": "OTP sent to your email"}, status=status.HTTP_200_OK)
        except serializers.ValidationError as exc:
            return Response({"errors": exc.detail}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as exc:
            logger.error("Forgot password error: %s", exc)
            return Response({"error": "Internal server error"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ResetOtpVerifyView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [OTPThrottle]

    def post(self, request):
        serializer = ResetOtpVerifySerializer(data=request.data)
        try:
            serializer.is_valid(raise_exception=True)
            user = serializer.validated_data['user']
            refresh = RefreshToken.for_user(user)
            return Response({"msg": "OTP verified", "reset_token": str(refresh.access_token)},
                            status=status.HTTP_200_OK)
        except serializers.ValidationError as exc:
            return Response({"errors": exc.detail}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as exc:
            logger.error("Reset OTP verification error: %s", exc)
            return Response({"error": "Internal server error"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ResetPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ResetPasswordSerializer(data=request.data)
        try:
            serializer.is_valid(raise_exception=True)
            serializer.save()
            return Response({"msg": "Password reset successful"}, status=status.HTTP_200_OK)
        except serializers.ValidationError as exc:
            return Response({"errors": exc.detail}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as exc:
            logger.error("Password reset error: %s", exc)
            return Response({"error": "Internal server error"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ResendOtpView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [OTPThrottle]

    def post(self, request):
        serializer = ResendOtpCodeSerializer(data=request.data)
        try:
            serializer.is_valid(raise_exception=True)
            serializer.save()
            return Response({"message": "OTP resent successfully"}, status=status.HTTP_200_OK)
        except serializers.ValidationError as exc:
            return Response({"errors": exc.detail}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as exc:
            logger.error("Resend OTP error: %s", exc)
            return Response({"error": "Internal server error"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class PasswordResetResendOTPView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [OTPThrottle]

    def post(self, request):
        serializer = ResendForgotOtpSerializer(data=request.data)
        try:
            serializer.is_valid(raise_exception=True)
            serializer.save()
            return Response({"msg": "OTP resent successfully"}, status=status.HTTP_200_OK)
        except serializers.ValidationError as exc:
            return Response({"errors": exc.detail}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as exc:
            logger.error("Resend password reset OTP error: %s", exc)
            return Response({"error": "Internal server error"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(
            data=request.data,
            context={'user': request.user}
        )
        if not serializer.is_valid():
           return Response({"errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)
        user=request.user
        if not user.check_password(serializer.validated_data['current_password']):
            SuspiciousActivityLog.objects.create(
                user=user,
                activity_type='password_change',
                threat_level='HIGH',
                ip_address=get_client_ip(request),
                details={'reason':'Wrong Current Password Supplied'},
                action_taken='blocked'
            )
            return Response(
                {'msg':'Current Password is not correct'},status=status.HTTP_400_BAD_REQUEST
            )
        if not user.otp_code or user.otp_code!=serializer.validated_data['otp_code']:
            return Response({"error":"Invalid OTP"},status=status.HTTP_400_BAD_REQUEST)
        if  user.otp_created_at and timezone.now()>user.otp_created_at+timedelta(minutes=10):
            return Response({
                'error':'OTP has expired'
            },status=status.HTTP_400_BAD_REQUEST
            ,
            )
        if user.check_password(serializer.validated_data['password']):
            return Response({'msg':'New Password Must be different from the old password'},status=status.HTTP_400_BAD_REQUEST)
        with transaction.atomic():
            user.set_password(serializer.validated_data['password'])
            user.otp_code=None
            user.otp_created_at=None
            user.password_changed_at=timezone.now()
            user.save()

        tokens=OutstandingToken.objects.filter(user=user)
        for token in tokens:
            BlacklistedToken.objects.get_or_create(token=token)

        DeviceInfo.objects.filter(user=user).update(
            is_verified=False,
            is_trusted=False
        )
        SuspiciousActivityLog.objects.create(
            user=user,
            activity_type='password_change',
            threat_level='LOW',
                ip_address=get_client_ip(request),
                details={
                    'action': 'password changed successfully',
                    'devices_blacklisted': DeviceInfo.objects.filter(user=user).count(),
                },
                action_taken='logged',
            )
        send_security_notification_from_view(
            user_id=user.id,
            notification_type='password_changed',
            context={
                'ip':get_client_ip(request),
                'time':timezone.now().strftime('%Y-%m-%d %H:%M UTC'),
                'device':request.META.get('HTTP_USER_AGENT','UNKNOWN')
            },
        )
        refresh=RefreshToken.for_user(user)
        return Response({
            "msg":"Password Changed Successfully.All Other session have been terminated",
            "token":{
                "refresh": str(refresh),
                "access": str(refresh.access_token),
            }
        },status=status.HTTP_200_OK)

class RequestPasswordChangeOTPView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        """
        User hits this first — we send OTP to their email.
        They then call ChangePasswordView with that OTP.
        """
        user = request.user
        otp = ''.join([str(secrets.randbelow(10)) for _ in range(6)])
        user.otp_code = otp
        user.otp_created_at = timezone.now()
        user.save(update_fields=['otp_code', 'otp_created_at'])

        send_security_notification_from_view(
            user_id=user.id,
            notification_type='password_change_otp',
            context={
                'otp': otp,
                'ip': get_client_ip(request),
                'time': timezone.now().strftime('%Y-%m-%d %H:%M UTC'),
            },
        )
        return Response(
            {"msg": "OTP sent to your registered email address"},
            status=status.HTTP_200_OK,
        )


class LogoutView(APIView):
    permission_classes=[IsAuthenticated]
    def post(self,request):
        try:
            refresh_token=request.data['refresh']
            token=RefreshToken(refresh_token)
            token.blacklist()
            return Response({"msg":"Logout Successful"},status=status.HTTP_205_RESET_CONTENT)
        except Exception as e:
            return Response({"msg":"Invalid Token"},status=status.HTTP_400_BAD_REQUEST)
            
# ---------------------------------------------------------------------------
# File views  — decrypt_file() / decrypt_image() now called from utils
# ---------------------------------------------------------------------------

class UploadFileView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if 'file' not in request.FILES:
            return Response({"error": "No file provided"}, status=status.HTTP_400_BAD_REQUEST)
# contains the multipart file uploaded
        uploaded = request.FILES['file']
        file_content = uploaded.read()

        try:
            with transaction.atomic():
                crypto = encrypt_file(file_content)
                encrypted_name = generate_encrypted_file_name(uploaded.name)
                file_path = os.path.join('encrypted', encrypted_name)
                default_storage.save(file_path, ContentFile(crypto['ciphertext']))

                ef = EncryptedFile.objects.create(
                    user=request.user,
                    original_name=uploaded.name,
                    encrypted_name=encrypted_name,
                    file_type=uploaded.content_type,
                    file_size=uploaded.size,
                    encrypted_aes_key=crypto['encrypted_aes_key'],
                    key_wrap_nonce=crypto['key_wrap_nonce'],
                    key_wrap_tag=crypto['key_wrap_tag'],
                    file_nonce=crypto['file_nonce'],
                    file_tag=crypto['file_tag'],
                )
                _log_file_access(ef, request.user, 'UPLOAD', request)
                return Response({'status': 'Success', 'file_id': ef.id,
                                 'encrypted_name': encrypted_name}, status=status.HTTP_201_CREATED)
        except Exception as exc:
            logger.error("File upload error: %s", exc)
            return Response({"error": str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DownloadFileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, file_id):
        try:
            ef = EncryptedFile.objects.select_related('user').get(id=file_id)
            if ef.user != request.user:
                _unauthorized_access_log(request.user, 'file_access', 'file_id', file_id, request)
                return HttpResponseForbidden("Access Denied")

            content = decrypt_file(ef, request)
            _log_file_access(ef, request.user, 'DOWNLOAD', request)

            response = FileResponse(ContentFile(content), content_type=ef.file_type)
            # Content Diposition defines how the content should be handled attachment means the file should be downloadable and inline means it should be shown in the browser at that time only.
            response['Content-Disposition'] = f'attachment; filename="{ef.original_name}"'
            return response
        except EncryptedFile.DoesNotExist:
            return Response({"error": "File not found"}, status=status.HTTP_404_NOT_FOUND)
        except ValueError as exc:
            # GCM tamper detected — already logged inside decrypt_file
            return Response({"error": "File integrity check failed"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        except Exception as exc:
            logger.error("File download error: %s", exc)
            return Response({"error": str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class FileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, file_id):
        try:
            ef = EncryptedFile.objects.select_related('user').get(id=file_id)
            if ef.user != request.user:
                _unauthorized_access_log(request.user, 'file_access', 'file_id', file_id, request)
                return HttpResponseForbidden("Access Denied")

            content = decrypt_file(ef, request)
            _log_file_access(ef, request.user, 'VIEW', request)

            response = FileResponse(ContentFile(content), content_type=ef.file_type)
            response['Content-Disposition'] = f'inline; filename="{ef.original_name}"'
            return response
        except EncryptedFile.DoesNotExist:
            return Response({"msg": "File not found"}, status=status.HTTP_404_NOT_FOUND)
        except ValueError:
            return Response({"error": "File integrity check failed"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        except Exception as exc:
            logger.error("File view error: %s", exc)
            return Response({"error": str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ListFilesView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            files = EncryptedFile.objects.filter(user=request.user).values(
                'id', 'original_name', 'file_type', 'file_size', 'upload_date',
            )
            return Response(list(files), status=status.HTTP_200_OK)
        except Exception as exc:
            return Response({"error": str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AccessLogView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, file_id):
        try:
            ef = EncryptedFile.objects.get(id=file_id, user=request.user)
            logs = FileAccessLog.objects.filter(file=ef).select_related(
                'user', 'device', 'location',
            ).values(
                'id', 'user__email', 'access_time', 'action', 'ip_address',
                'device__device_id', 'location__city', 'location__country',
                'is_suspicious', 'threat_level',
            )
            return Response(list(logs), status=status.HTTP_200_OK)
        except EncryptedFile.DoesNotExist:
            return Response({"error": "File does not exist or you do not have permission"},
                            status=status.HTTP_404_NOT_FOUND)
        except Exception as exc:
            return Response({"error": str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DeleteFileView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, file_id):
        try:
            with transaction.atomic():
                ef = EncryptedFile.objects.select_for_update().get(id=file_id)
                if ef.user != request.user:
                    _unauthorized_access_log(request.user, 'file_access', 'file_id', file_id, request)
                    return Response({"msg": "Not authorized"}, status=status.HTTP_403_FORBIDDEN)

                path = os.path.join('encrypted', ef.encrypted_name)
                if default_storage.exists(path):
                    default_storage.delete(path)

                _log_file_access(ef, request.user, 'DELETE', request)
                ef.delete()
                return Response({"msg": "File deleted successfully"}, status=status.HTTP_204_NO_CONTENT)
        except EncryptedFile.DoesNotExist:
            return Response({"msg": "File not found"}, status=status.HTTP_404_NOT_FOUND)
        except Exception as exc:
            logger.error("File delete error: %s", exc)
            return Response({"msg": f"Error deleting file: {exc}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# Alias kept for backward compatibility
DeleteFile = DeleteFileView


# ---------------------------------------------------------------------------
# Image views
# ---------------------------------------------------------------------------

class UploadImageView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if 'file' not in request.FILES:
            return Response({"error": "No image provided"}, status=status.HTTP_400_BAD_REQUEST)

        uploaded = request.FILES['file']
        image_content = uploaded.read()

        try:
            with transaction.atomic():
                crypto = encrypt_image(image_content)
                encrypted_name = generate_encrypted_image_path(uploaded.name)
                file_path = os.path.join('EncryptedImage', encrypted_name)
                default_storage.save(file_path, ContentFile(crypto['ciphertext']))

                ei = EncryptedImage.objects.create(
                    user=request.user,
                    original_name=uploaded.name,
                    encrypted_name=encrypted_name,
                    image_type=uploaded.content_type,
                    image_size=uploaded.size,
                    encrypted_aes_key=crypto['encrypted_aes_key'],
                    key_wrap_nonce=crypto['key_wrap_nonce'],
                    key_wrap_tag=crypto['key_wrap_tag'],
                    file_nonce=crypto['file_nonce'],
                    file_tag=crypto['file_tag'],
                )
                _log_image_access(ei, request.user, 'UPLOAD', request)
                return Response({'status': 'Success', 'image_id': ei.id,
                                 'encrypted_name': encrypted_name}, status=status.HTTP_201_CREATED)
        except Exception as exc:
            logger.error("Image upload error: %s", exc)
            return Response({"error": str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DownloadImageView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, image_id):
        try:
            ei = EncryptedImage.objects.select_related('user').get(id=image_id)
            if ei.user != request.user:
                _unauthorized_access_log(request.user, 'image_access', 'image_id', image_id, request)
                return HttpResponseForbidden("Access Denied")

            content = decrypt_image(ei, request)
            _log_image_access(ei, request.user, 'DOWNLOAD', request)

            response = FileResponse(ContentFile(content), content_type=ei.image_type)
            response['Content-Disposition'] = f'attachment; filename="{ei.original_name}"'
            return response
        except EncryptedImage.DoesNotExist:
            return Response({"error": "Image not found"}, status=status.HTTP_404_NOT_FOUND)
        except ValueError:
            return Response({"error": "Image integrity check failed"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        except Exception as exc:
            logger.error("Image download error: %s", exc)
            return Response({"error": str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ImageView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, image_id):
        try:
            ei = EncryptedImage.objects.select_related('user').get(id=image_id)
            if ei.user != request.user:
                _unauthorized_access_log(request.user, 'image_access', 'image_id', image_id, request)
                return HttpResponseForbidden("Access Denied")

            content = decrypt_image(ei, request)
            _log_image_access(ei, request.user, 'VIEW', request)

            response = FileResponse(ContentFile(content), content_type=ei.image_type)
            response['Content-Disposition'] = f'inline; filename="{ei.original_name}"'
            return response
        except EncryptedImage.DoesNotExist:
            return Response({'msg': 'Image not found'}, status=status.HTTP_404_NOT_FOUND)
        except ValueError:
            return Response({"error": "Image integrity check failed"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        except Exception as exc:
            logger.error("Image view error: %s", exc)
            return Response({'msg': str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ListImageView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            images = EncryptedImage.objects.filter(user=request.user).values(
                'id', 'original_name', 'image_type', 'image_size', 'upload_date',
            )
            return Response(list(images), status=status.HTTP_200_OK)
        except Exception as exc:
            return Response({"error": str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ImageAccessLogView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, image_id):
        try:
            ei = EncryptedImage.objects.get(id=image_id, user=request.user)
            logs = ImageAccessLog.objects.filter(image=ei).select_related(
                'user', 'device', 'location',
            ).values(
                'id', 'user__email', 'access_time', 'action', 'ip_address',
                'device__device_id', 'location__city', 'location__country',
                'is_suspicious', 'threat_level',
            )
            return Response(list(logs), status=status.HTTP_200_OK)
        except EncryptedImage.DoesNotExist:
            return Response({"error": "Image does not exist or you do not have permission"},
                            status=status.HTTP_404_NOT_FOUND)
        except Exception as exc:
            return Response({"error": str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DeleteImagesView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, image_id):
        try:
            with transaction.atomic():
                ei = EncryptedImage.objects.select_for_update().get(id=image_id)
                if ei.user != request.user:
                    _unauthorized_access_log(request.user, 'image_access', 'image_id', image_id, request)
                    return Response({"msg": "Not authorized"}, status=status.HTTP_403_FORBIDDEN)

                path = os.path.join('EncryptedImage', ei.encrypted_name)
                if default_storage.exists(path):
                    default_storage.delete(path)

                _log_image_access(ei, request.user, 'DELETE', request)
                ei.delete()
                return Response({"msg": "Image deleted successfully"}, status=status.HTTP_204_NO_CONTENT)
        except EncryptedImage.DoesNotExist:
            return Response({"msg": "Image not found"}, status=status.HTTP_404_NOT_FOUND)
        except Exception as exc:
            logger.error("Image delete error: %s", exc)
            return Response({"msg": f"Error deleting image: {exc}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
class UpdateProfileView(APIView):
    permission_classes = [IsAuthenticated]

    
    def patch(self, request):
        serializer = UpdateProfileSerializer(
            instance=request.user,
            data=request.data,
            partial=True  
        )

        try:
            
            old_image = request.user.image.path if request.user.image else None
            
            serializer.is_valid(raise_exception=True)
            serializer.save()  

            
            if 'image' in request.data and old_image and os.path.exists(old_image):
                os.remove(old_image)

            return Response(serializer.data, status=status.HTTP_200_OK)

        except serializers.ValidationError as exc:
           
            return Response({"errors": exc.detail}, status=status.HTTP_400_BAD_REQUEST)
            
        except Exception as exc:
            logger.error("Profile update error: %s", exc)
            return Response(
                {"msg": "Internal Server error"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
class GetUserProfile(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = GetUserProfileSerializer(request.user)
        return Response({"msg": serializer.data}, status=status.HTTP_200_OK)




# ---------------------------------------------------------------------------
# Share link views
# ---------------------------------------------------------------------------

class CreateShareLinkView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        resource_type = request.data.get('resource_type', '').lower()
        resource_id = request.data.get('resource_id')

        if resource_type not in ('file', 'image'):
            return Response({"msg": "Invalid resource type"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            with transaction.atomic():
                if resource_type == 'file':
                    resource = EncryptedFile.objects.get(id=resource_id, user=request.user)
                else:
                    resource = EncryptedImage.objects.get(id=resource_id, user=request.user)

                shared = SharedFileResource.objects.create(
                    resource_type=resource_type,
                    file=resource if resource_type == 'file' else None,
                    image=resource if resource_type == 'image' else None,
                    creator=request.user,
                    expires_at=timezone.now() + timedelta(minutes=10),
                )
                shared_url = request.build_absolute_uri(f'/api/sharedresource/{shared.id}')
                return Response({
                    "msg": "Share link created successfully",
                    "shared_url": shared_url,
                    "expires_at": shared.expires_at,
                }, status=status.HTTP_200_OK)

        except (EncryptedFile.DoesNotExist, EncryptedImage.DoesNotExist):
            return Response({"msg": "Resource not found or no permission"}, status=status.HTTP_404_NOT_FOUND)
        except Exception as exc:
            logger.error("Create share link error: %s", exc)
            return Response({"error": "Internal server error"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class SharedResourceView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [SharedResourceViewThrottle]

    def get(self, request, share_id):
        try:
            shared = (
                SharedFileResource.objects
                .select_related("file", "image", "creator")
                .get(id=share_id)
            )
        except SharedFileResource.DoesNotExist:
            return Response(
                {"error": "Invalid share link"},
                status=status.HTTP_404_NOT_FOUND,
            )

        if shared.expires_at and shared.expires_at < timezone.now():
            return Response({"msg": "Share link expired"}, status=status.HTTP_410_GONE)

        if shared.is_used:
            return Response({"msg": "Share link already used"}, status=status.HTTP_410_GONE)

        try:
            if shared.resource_type == "file":
                content = decrypt_file(shared.file, request)
                content_type = shared.file.file_type or "application/octet-stream"
                filename = shared.file.original_name
            else:
                content = decrypt_image(shared.image, request)
                content_type = shared.image.image_type or "image/png"
                filename = shared.image.original_name
        except ValueError:
            return Response(
                {"error": "File integrity check failed"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        except Exception as exc:
            logger.error("Decryption error share_id=%s: %s", share_id, exc, exc_info=True)
            return Response({"error": "Internal server error"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        client_ip = get_client_ip(request)

        try:
            html = self._generate_viewer(content, content_type, shared.resource_type, filename, client_ip)
            response = HttpResponse(html, content_type="text/html")
            self._add_security_headers(response)
        except Exception as exc:
            logger.error("Viewer render error share_id=%s: %s", share_id, exc, exc_info=True)
            return Response({"error": "Internal server error"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        shared.is_used = True
        shared.viewer_ip = client_ip
        shared.save(update_fields=["is_used", "viewer_ip"])

        return response

    def _generate_viewer(self, content, content_type, resource_type, filename, client_ip):
        b64 = base64.b64encode(content).decode("utf-8")
        logger.info("Viewer b64 size: %s KB for file: %s", len(b64) // 1024, filename)  
        wm = f"CONFIDENTIAL \u00a9 {timezone.now().strftime('%Y-%m-%d %H:%M')}"
        safe_filename = filename.replace('"', "&quot;").replace("<", "&lt;")
        safe_ip = client_ip.replace("<", "&lt;")

        if resource_type == "image":
            media_tag = (
                f'<img src="data:{content_type};base64,{b64}" '
                f'alt="{safe_filename}" class="main-content">'
            )
            media_script = ""
        else:
            # Use a div as container — canvas cannot have child elements
            media_tag = (
                '<div id="pdf-container" class="main-content" '
                'style="overflow-y:auto;display:flex;flex-direction:column;'
                'align-items:center;padding:16px 0;height:calc(100vh - 96px);"></div>'
            )
            media_script = f"""
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
<script>
(function () {{
    var b64 = "{b64}";

    pdfjsLib.GlobalWorkerOptions.workerSrc =
        'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';

    try {{
        var binary = atob(b64);
        var bytes = new Uint8Array(binary.length);
        for (var i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);

        pdfjsLib.getDocument({{ data: bytes }}).promise.then(function (pdf) {{
            var container = document.getElementById('pdf-container');
            var renderPage = function (pageNum) {{
                pdf.getPage(pageNum).then(function (page) {{
                    var viewport = page.getViewport({{ scale: 1.5 }});
                    var canvas = document.createElement('canvas');
                    var ctx = canvas.getContext('2d');
                    canvas.width = viewport.width;
                    canvas.height = viewport.height;
                    canvas.style.display = 'block';
                    canvas.style.marginBottom = '8px';
                    canvas.style.maxWidth = '100%';
                    canvas.style.boxShadow = '0 2px 12px rgba(0,0,0,0.4)';
                    container.appendChild(canvas);
                    page.render({{ canvasContext: ctx, viewport: viewport }});
                }}).catch(function (err) {{
                    var errDiv = document.createElement('div');
                    errDiv.style.cssText = 'color:#FC8181;padding:12px;text-align:center';
                    errDiv.textContent = 'Failed to render page ' + pageNum + ': ' + err.message;
                    document.getElementById('pdf-container').appendChild(errDiv);
                }});
            }};
            for (var p = 1; p <= pdf.numPages; p++) {{
                renderPage(p);
            }}
        }}).catch(function (err) {{
            document.getElementById('pdf-container').innerHTML =
                '<div style="color:#FC8181;padding:24px;text-align:center">Failed to load PDF: ' + err.message + '</div>';
        }});
    }} catch (e) {{
        document.getElementById('pdf-container').innerHTML =
            '<div style="color:#FC8181;padding:24px;text-align:center">Error decoding PDF data: ' + e.message + '</div>';
    }}
}})();
</script>"""

        return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>SecuredVault \u2014 {safe_filename}</title>
<link rel="icon" href="data:,">
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ font-family: 'Segoe UI', Roboto, sans-serif; background: #0D0D1A; color: #E2E8F0; height: 100vh; display: flex; flex-direction: column; overflow: hidden; }}
  .hdr {{ background: linear-gradient(135deg, #4361EE, #3A0CA3); padding: 14px 24px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 12px rgba(0,0,0,.4); flex-shrink: 0; }}
  .hdr-logo {{ font-weight: 700; font-size: 16px; color: #fff; letter-spacing: .5px; }}
  .hdr-meta {{ font-size: 12px; color: rgba(255,255,255,.7); }}
  .viewer {{ flex: 1; position: relative; display: flex; justify-content: center; align-items: flex-start; overflow: hidden; }}
  .main-content {{ width: 100%; }}
  img.main-content {{ max-width: 100%; max-height: calc(100vh - 96px); object-fit: contain; display: block; margin: auto; }}
  .watermark {{ position: fixed; bottom: 48px; right: 24px; font-size: 11px; color: rgba(255,255,255,.18); transform: rotate(-30deg); pointer-events: none; letter-spacing: 1px; font-weight: 600; z-index: 999; }}
  .ftr {{ background: #111128; padding: 10px 24px; display: flex; justify-content: space-between; align-items: center; border-top: 1px solid rgba(255,255,255,.08); flex-shrink: 0; }}
  .ftr-name {{ font-size: 13px; color: #A0AEC0; font-weight: 500; }}
  .ftr-ip {{ font-size: 11px; color: #4A5568; }}
  .badge {{ display: inline-flex; align-items: center; gap: 6px; background: rgba(239,35,60,.15); border: 1px solid rgba(239,35,60,.3); color: #FC8181; font-size: 11px; font-weight: 600; padding: 3px 10px; border-radius: 99px; letter-spacing: .3px; }}
  .dot {{ width: 6px; height: 6px; border-radius: 50%; background: #FC8181; animation: pulse 1.5s ease-in-out infinite; }}
  @keyframes pulse {{ 0%, 100% {{ opacity: 1; }} 50% {{ opacity: .3; }} }}
</style>
</head>
<body>
<header class="hdr">
  <div class="hdr-logo">SecuredVault</div>
  <div style="display:flex;align-items:center;gap:12px">
    <div class="badge"><div class="dot"></div>One-time link</div>
    <div class="hdr-meta">IP: {safe_ip}</div>
  </div>
</header>
<div class="viewer">
  {media_tag}
  <div class="watermark">{wm}</div>
</div>
<footer class="ftr">
  <div class="ftr-name">{safe_filename}</div>
  <div class="ftr-ip">Viewer: {safe_ip}</div>
</footer>
{media_script}
<script>
document.addEventListener("contextmenu", function(e) {{ e.preventDefault(); }});
document.addEventListener("keydown", function(e) {{
  if (
    e.key === "F12" ||
    (e.ctrlKey && e.shiftKey && ["I","J","C"].includes(e.key)) ||
    (e.ctrlKey && ["u","s","p"].includes(e.key.toLowerCase()))
  ) {{
    e.preventDefault();
  }}
}});
setTimeout(function() {{
  document.body.innerHTML =
    "<div style=\\"display:flex;justify-content:center;align-items:center;height:100vh;" +
    "background:#0D0D1A;color:#E2E8F0;font-family:sans-serif;flex-direction:column;gap:12px\\">" +
    "<div style=\\"font-size:48px\\">&#128274;</div>" +
    "<div style=\\"font-size:20px;font-weight:600\\">Session expired</div>" +
    "<div style=\\"font-size:14px;color:#718096\\">This secure link has expired</div></div>";
}}, 600000);
</script>
</body>
</html>"""

    def _add_security_headers(self, response):
        headers = {
            "X-Frame-Options": "DENY",
            "X-Content-Type-Options": "nosniff",
            "X-XSS-Protection": "1; mode=block",
            "Content-Security-Policy": (
                "default-src 'none'; "
                "script-src 'unsafe-inline' https://cdnjs.cloudflare.com; "
                "style-src 'unsafe-inline'; "
                "img-src data: blob:; "
                "frame-src blob:; "
                "connect-src 'none';"
            ),
            "Referrer-Policy": "no-referrer",
            "Permissions-Policy": "fullscreen=(), clipboard-write=()",
            "Cross-Origin-Opener-Policy": "same-origin",
            "Cross-Origin-Resource-Policy": "same-origin",
            "Cache-Control": "no-store, no-cache, must-revalidate, private",
            "Pragma": "no-cache",
        }
        for key, value in headers.items():
            response[key] = value
# ---------------------------------------------------------------------------
# Room & P2P views
# ---------------------------------------------------------------------------

class RoomListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        rooms = Room.objects.filter(is_active=True, owner=request.user)
        return Response(RoomSerializer(rooms, many=True).data)

    def post(self, request):
        serializer = RoomCreateSerializer(data=request.data)
        if serializer.is_valid():
            room = serializer.save(owner=request.user)
            return Response({
                'room': RoomSerializer(room).data,
                'message': f'Room created. Passcode: {room.passcode}',
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class RoomDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def _get_room(self, pk, user):
        return get_object_or_404(Room, pk=pk, is_active=True, owner=user)

    def get(self, request, pk):
        return Response(RoomSerializer(self._get_room(pk, request.user)).data)

    def put(self, request, pk):
        room = self._get_room(pk, request.user)
        serializer = RoomSerializer(room, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        room = self._get_room(pk, request.user)
        room.is_active = False
        room.save(update_fields=['is_active'])
        return Response(status=status.HTTP_204_NO_CONTENT)


class RoomJoinView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = RoomJoinSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        try:
            room = Room.objects.get(
                id=serializer.validated_data['room_id'],
                passcode=serializer.validated_data['passcode'],
                is_active=True,
            )
        except Room.DoesNotExist:
            return Response({'error': 'Invalid passcode or room not found'}, status=status.HTTP_404_NOT_FOUND)

        if room.peers.filter(is_connected=True, is_authenticated=True).count() >= room.max_peers:
            return Response({'error': 'Room is full'}, status=status.HTTP_403_FORBIDDEN)

        peer, _ = Peer.objects.update_or_create(
            room=room,
            peer_id=serializer.validated_data['peer_id'],
            defaults={
                'user': request.user,
                'device_name': serializer.validated_data.get('device_name', 'Unknown'),
                'is_authenticated': True,
                'is_connected': True,
            },
        )
        return Response({
            'room': RoomSerializer(room).data,
            'peer': PeerSerializer(peer).data,
            'message': 'Successfully joined room',
        }, status=status.HTTP_200_OK)


class RoomPeersView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        room = get_object_or_404(Room, pk=pk, is_active=True, owner=request.user)
        peers = room.peers.filter(is_connected=True, is_authenticated=True)
        return Response(PeerSerializer(peers, many=True).data)


# ---------------------------------------------------------------------------
# File transfer views
# ---------------------------------------------------------------------------

class FileTransferListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        transfers = (
            FileTransfer.objects.filter(sender=request.user) |
            FileTransfer.objects.filter(receiver=request.user)
        )
        return Response(FileTransferSerializer(transfers, many=True).data)

    def post(self, request):
        serializer = FileTransferInitSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        try:
            receiver_peer = Peer.objects.get(
                peer_id=serializer.validated_data['receiver_id'],
                room_id=serializer.validated_data['room_id'],
                is_connected=True,
            )
        except Peer.DoesNotExist:
            return Response({'error': 'Receiver peer not found'}, status=status.HTTP_404_NOT_FOUND)

        transfer = FileTransfer.objects.create(
            sender=request.user,
            receiver=receiver_peer.user,
            room_id=serializer.validated_data['room_id'],
            file_name=serializer.validated_data['file_name'],
            file_size=serializer.validated_data['file_size'],
            file_type=serializer.validated_data['file_type'],
            chunk_count=serializer.validated_data['chunk_count'],
            # E2EE fields from serializer
            sender_public_key=serializer.validated_data.get('sender_public_key', ''),
            sender_signature=base64.b64decode(serializer.validated_data['sender_signature']) if serializer.validated_data.get('sender_signature') else None,
            payload_hash=serializer.validated_data.get('payload_hash', ''),
            encrypted_aes_key=base64.b64decode(serializer.validated_data['encrypted_aes_key']) if serializer.validated_data.get('encrypted_aes_key') else None,
            file_nonce=base64.b64decode(serializer.validated_data['file_nonce']) if serializer.validated_data.get('file_nonce') else None,
            file_tag=base64.b64decode(serializer.validated_data['file_tag']) if serializer.validated_data.get('file_tag') else None,
        )
        return Response({'transfer_id': str(transfer.id), 'message': 'Transfer initiated'},
                        status=status.HTTP_201_CREATED)


class FileTransferDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def _get(self, pk, user):
        try:
            t = FileTransfer.objects.get(pk=pk)
            return t if t.sender == user or t.receiver == user else None
        except FileTransfer.DoesNotExist:
            return None

    def get(self, request, pk):
        t = self._get(pk, request.user)
        if t is None:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        return Response(FileTransferSerializer(t).data)

    def put(self, request, pk):
        t = self._get(pk, request.user)
        if t is None:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        serializer = FileTransferSerializer(t, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        t = self._get(pk, request.user)
        if t is None:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        t.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class FileTransferCompleteView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            t = FileTransfer.objects.get(pk=pk)
        except FileTransfer.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        if t.receiver != request.user:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        t.status = 'completed'
        t.completed_at = timezone.now()
        t.save(update_fields=['status', 'completed_at'])
        return Response({'message': 'Transfer marked as completed'})


class FileTransferUpdateChunkView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            t = FileTransfer.objects.get(pk=pk)
        except FileTransfer.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        if t.receiver != request.user:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        chunks = request.data.get('chunks_received', 0)
        if chunks > t.chunk_count:
            return Response({'error': 'Invalid chunk count'}, status=status.HTTP_400_BAD_REQUEST)
        t.chunks_received = chunks
        t.status = 'in_progress'
        t.save(update_fields=['chunks_received', 'status'])
        return Response({'message': 'Chunk count updated'})


class DashboardView(APIView):
    """
    Aggregated dashboard data for the authenticated user.
    Returns daily counts for the last 7 days + summary statistics.
    """
    permission_classes = [IsAuthenticated]
    throttle_classes = [BurstThrottle]

    def get(self, request):
        user = request.user
        now = timezone.now()
        seven_days_ago = now - timedelta(days=7)

        # ---------- daily activity (last 7 days) ----------
        file_logs = (
            FileAccessLog.objects.filter(user=user, access_time__gte=seven_days_ago)
            .values('access_time__date')
            .annotate(count=models.Count('id'))
            .order_by('access_time__date')
        )
        image_logs = (
            ImageAccessLog.objects.filter(user=user, access_time__gte=seven_days_ago)
            .values('access_time__date')
            .annotate(count=models.Count('id'))
            .order_by('access_time__date')
        )
        suspicious_logs = (
            SuspiciousActivityLog.objects.filter(user=user, timestamp__gte=seven_days_ago)
            .values('timestamp__date')
            .annotate(count=models.Count('id'))
            .order_by('timestamp__date')
        )
        login_logs = (
            LoginAttempt.objects.filter(user=user, timestamp__gte=seven_days_ago)
            .values('timestamp__date')
            .annotate(count=models.Count('id'))
            .order_by('timestamp__date')
        )

        # Build day-by-day map for all 7 days
        daily = {}
        for i in range(7):
            day = (seven_days_ago + timedelta(days=i)).date()
            daily[str(day)] = {
                'date': str(day),
                'file_access': 0,
                'image_access': 0,
                'suspicious': 0,
                'logins': 0,
            }

        for row in file_logs:
            key = str(row['access_time__date'])
            if key in daily:
                daily[key]['file_access'] = row['count']
        for row in image_logs:
            key = str(row['access_time__date'])
            if key in daily:
                daily[key]['image_access'] = row['count']
        for row in suspicious_logs:
            key = str(row['timestamp__date'])
            if key in daily:
                daily[key]['suspicious'] = row['count']
        for row in login_logs:
            key = str(row['timestamp__date'])
            if key in daily:
                daily[key]['logins'] = row['count']

        daily_list = list(daily.values())

        # ---------- summary totals ----------
        total_files = EncryptedFile.objects.filter(user=user).count()
        total_images = EncryptedImage.objects.filter(user=user).count()
        total_file_accesses = FileAccessLog.objects.filter(user=user).count()
        total_image_accesses = ImageAccessLog.objects.filter(user=user).count()
        total_suspicious = SuspiciousActivityLog.objects.filter(user=user).count()
        total_logins = LoginAttempt.objects.filter(user=user).count()
        failed_logins = LoginAttempt.objects.filter(user=user, status='failed').count()

        # ---------- suspicious breakdown by type ----------
        suspicious_by_type = list(
            SuspiciousActivityLog.objects.filter(user=user)
            .values('activity_type')
            .annotate(count=models.Count('id'))
            .order_by('-count')
        )

        # ---------- suspicious breakdown by threat level ----------
        suspicious_by_threat = list(
            SuspiciousActivityLog.objects.filter(user=user)
            .values('threat_level')
            .annotate(count=models.Count('id'))
            .order_by('-count')
        )

        # ---------- recent suspicious events ----------
        recent_suspicious = list(
            SuspiciousActivityLog.objects.filter(user=user)
            .order_by('-timestamp')[:5]
            .values('activity_type', 'threat_level', 'ip_address', 'timestamp', 'action_taken')
        )
        # Make timestamps serializable
        for item in recent_suspicious:
            item['timestamp'] = item['timestamp'].isoformat()
            
        # ---------- active devices ----------
        devices_qs = DeviceInfo.objects.filter(user=user).order_by('-last_used')[:10]
        devices = []
        for d in devices_qs:
            devices.append({
                'id': d.id,
                'device_name': d.device_name or d.model or 'Unknown Device',
                'os': d.os or 'Unknown OS',
                'browser_info': d.browser_info or '',
                'last_used': d.last_used.isoformat() if d.last_used else None,
                'is_trusted': d.is_trusted,
                'login_count': d.login_count,
            })

        return Response({
            'daily': daily_list,
            'summary': {
                'total_files': total_files,
                'total_images': total_images,
                'total_file_accesses': total_file_accesses,
                'total_image_accesses': total_image_accesses,
                'total_suspicious': total_suspicious,
                'total_logins': total_logins,
                'failed_logins': failed_logins,
            },
            'suspicious_by_type': suspicious_by_type,
            'suspicious_by_threat': suspicious_by_threat,
            'recent_suspicious': recent_suspicious,
            'devices': devices,
        })


# ---------------------------------------------------------------------------
# E2EE Public Key Exchange
# ---------------------------------------------------------------------------

class PublicKeyExchangeView(APIView):
    """
    Store and retrieve public keys for E2EE file sharing.

    POST — store the calling user's RSA and Ed25519 public keys
    GET  — fetch another user's public keys by user_id query param

    Private keys NEVER touch the server — only public keys are stored.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        """Store the caller's public keys (PEM-encoded)."""
        rsa_pub = request.data.get('rsa_public_key')
        ed25519_pub = request.data.get('ed25519_public_key')

        if not rsa_pub or not ed25519_pub:
            return Response(
                {'error': 'Both rsa_public_key and ed25519_public_key are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Basic PEM format sanity check
        if '-----BEGIN PUBLIC KEY-----' not in rsa_pub:
            return Response(
                {'error': 'rsa_public_key must be PEM-encoded'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        request.user.rsa_public_key = rsa_pub
        request.user.ed25519_public_key = ed25519_pub
        request.user.save(update_fields=['rsa_public_key', 'ed25519_public_key'])

        logger.info("Public keys stored for user %s", request.user.email)
        return Response({'message': 'Public keys stored successfully'})

    def get(self, request):
        """Fetch another user's public keys for E2EE."""
        user_id = request.query_params.get('user_id')
        if not user_id:
            return Response(
                {'error': 'user_id query parameter is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            target_user = MyUser.objects.get(id=user_id)
        except MyUser.DoesNotExist:
            return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

        if not target_user.rsa_public_key or not target_user.ed25519_public_key:
            return Response(
                {'error': 'User has not registered their public keys yet'},
                status=status.HTTP_404_NOT_FOUND,
            )

        return Response({
            'user_id': target_user.id,
            'email': target_user.email,
            'name': target_user.name,
            'rsa_public_key': target_user.rsa_public_key,
            'ed25519_public_key': target_user.ed25519_public_key,
        })
