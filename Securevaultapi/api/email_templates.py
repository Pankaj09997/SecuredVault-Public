"""
Centralized HTML email templates for SecuredVault.

Every outbound email (OTP, security alerts, device verification, etc.)
uses these templates so the user always sees a professional, branded
container — never raw plain text.
"""
from django.conf import settings
from django.utils import timezone


# ── Shared colour palette (matched to SecuredVault logo) ───────────────────
_P = {
    'brand':       '#56CCF2',   # Cyan from logo top
    'brand_dark':  '#7B5EA7',   # Purple from logo bottom
    'navy':        '#0D1B2A',   # Deep navy background
    'navy_light':  '#1B2D45',   # Slightly lighter navy
    'accent':      '#A78BFA',   # Soft violet accent
    'success':     '#34D399',   # Emerald green
    'warning':     '#FBBF24',   # Amber
    'danger':      '#F87171',   # Soft red
    'critical':    '#EF4444',   # Red
    'text':        '#E2E8F0',   # Light text for dark backgrounds
    'text_dark':   '#1E293B',   # Dark text for light cards
    'muted':       '#94A3B8',   # Slate muted
    'bg':          '#0F172A',   # Dark page background
    'card':        '#1E293B',   # Dark card surface
    'card_light':  '#FFFFFF',   # Light card (for email clients that need it)
    'border':      '#334155',   # Subtle dark border
    'border_light':'#E2E8F0',   # Light border
}


# ── Reusable shell ─────────────────────────────────────────────────────────
def _shell(title: str, inner_html: str, accent_color: str | None = None) -> str:
    """Wrap *inner_html* in a responsive, branded email shell."""
    accent = accent_color or _P['brand']
    year = timezone.now().year
    support = settings.DEFAULT_FROM_EMAIL

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
        background:{_P['bg']};color:{_P['text']};line-height:1.6;
        -webkit-font-smoothing:antialiased;margin:0;padding:0}}
  a{{color:{_P['brand']};text-decoration:none}}
  .wrapper{{width:100%;background:{_P['bg']};padding:40px 16px}}
  .container{{max-width:560px;margin:0 auto}}
  /* ── header ── */
  .hdr{{background:linear-gradient(135deg,{_P['navy']},{_P['navy_light']});
        border-radius:16px 16px 0 0;padding:32px 32px;text-align:center;
        border:1px solid {_P['border']};border-bottom:none}}
  .hdr-icon{{font-size:36px;margin-bottom:8px}}
  .hdr-title{{background:linear-gradient(135deg,{_P['brand']},{_P['accent']});
              -webkit-background-clip:text;-webkit-text-fill-color:transparent;
              background-clip:text;font-size:22px;font-weight:800;letter-spacing:-0.3px}}
  .hdr-sub{{color:{_P['muted']};font-size:13px;margin-top:6px}}
  /* ── card ── */
  .card{{background:{_P['card']};padding:32px;
         border:1px solid {_P['border']};border-top:none}}
  .card h2{{font-size:18px;font-weight:700;color:{_P['text']};margin-bottom:6px}}
  .card .lead{{font-size:14px;color:{_P['muted']};margin-bottom:24px;line-height:1.6}}
  /* ── OTP box ── */
  .otp-box{{text-align:center;margin:24px 0}}
  .otp-code{{display:inline-block;font-size:32px;font-weight:800;
             letter-spacing:8px;color:{_P['brand']};
             background:{_P['navy']};padding:16px 32px;
             border-radius:12px;border:2px solid {_P['border']}}}
  .otp-expires{{font-size:12px;color:{_P['muted']};margin-top:10px}}
  /* ── detail table ── */
  .dtable{{width:100%;border-collapse:collapse;margin:20px 0}}
  .dtable td{{padding:10px 14px;font-size:13px;
              border-bottom:1px solid {_P['border']}}}\
  .dtable td:first-child{{color:{_P['muted']};font-weight:600;
                           white-space:nowrap;width:38%}}
  .dtable td:last-child{{color:{_P['text']};font-weight:500}}
  .dtable tr:last-child td{{border-bottom:none}}
  /* ── CTA button ── */
  .btn{{display:inline-block;padding:13px 28px;
        background:linear-gradient(135deg,{_P['brand']},{_P['accent']});
        color:{_P['navy']}!important;font-size:14px;font-weight:700;
        border-radius:8px;text-align:center;letter-spacing:0.2px;
        text-decoration:none}}
  .btn-danger{{background:linear-gradient(135deg,{_P['danger']},{_P['critical']});color:#fff!important}}
  .btn-row{{text-align:center;margin:24px 0}}
  /* ── divider ── */
  .divider{{border:none;border-top:1px solid {_P['border']};margin:24px 0}}
  /* ── notice box ── */
  .notice{{background:rgba(251,191,36,0.08);border-radius:8px;padding:14px 18px;
           font-size:13px;color:{_P['warning']};border-left:4px solid {_P['warning']};
           margin:20px 0}}
  /* ── footer ── */
  .ftr{{background:{_P['navy']};border-radius:0 0 16px 16px;padding:20px 32px;
        text-align:center;border:1px solid {_P['border']};border-top:none}}
  .ftr p{{font-size:12px;color:{_P['muted']};margin-bottom:4px}}
  .ftr a{{color:{_P['brand']};font-weight:600}}
  /* ── responsive ── */
  @media(max-width:600px){{
    .card,.hdr,.ftr{{padding:24px 20px}}
    .otp-code{{font-size:24px;letter-spacing:6px;padding:12px 20px}}
    .dtable td:first-child{{width:auto}}
  }}
</style>
</head>
<body>
<div class="wrapper">
  <div class="container">
    <div class="hdr">
      <div class="hdr-icon">🔒</div>
      <div class="hdr-title">SecuredVault</div>
      <div class="hdr-sub">{title}</div>
    </div>
    <div class="card">
      {inner_html}
    </div>
    <div class="ftr">
      <p>You received this because this action was triggered on your account.</p>
      <p>Questions? <a href="mailto:{support}">{support}</a></p>
      <p style="margin-top:8px;color:#475569">&copy; {year} SecuredVault. All rights reserved.</p>
    </div>
  </div>
</div>
</body>
</html>"""


def _row(label: str, value: str) -> str:
    return f'<tr><td>{label}</td><td>{value}</td></tr>'


def _btn(text: str, url: str, danger: bool = False) -> str:
    cls = 'btn btn-danger' if danger else 'btn'
    return f'<div class="btn-row"><a href="{url}" class="{cls}">{text}</a></div>'


# ── Public template functions ──────────────────────────────────────────────

def registration_otp_email(otp_code: str) -> tuple[str, str, str]:
    """Return (subject, html, plain) for the registration verification OTP."""
    subject = 'Verify your email — SecuredVault'
    inner = f"""
      <h2>Email Verification</h2>
      <p class="lead">
        Welcome to SecuredVault! Please use the verification code below
        to complete your registration.
      </p>
      <div class="otp-box">
        <div class="otp-code">{otp_code}</div>
        <div class="otp-expires">This code expires in 10 minutes</div>
      </div>
      <hr class="divider">
      <div class="notice">
        If you did not create a SecuredVault account, you can safely ignore this email.
      </div>"""
    html = _shell(subject, inner)
    plain = (
        f"Your SecuredVault verification code is: {otp_code}\n\n"
        f"This code expires in 10 minutes.\n"
        f"If you did not request this, please ignore this email."
    )
    return subject, html, plain


def resend_otp_email(otp_code: str) -> tuple[str, str, str]:
    """Return (subject, html, plain) for a resent registration OTP."""
    subject = 'Your new verification code — SecuredVault'
    inner = f"""
      <h2>New Verification Code</h2>
      <p class="lead">
        You requested a new verification code.
        Use the code below to complete your registration.
      </p>
      <div class="otp-box">
        <div class="otp-code">{otp_code}</div>
        <div class="otp-expires">This code expires in 10 minutes</div>
      </div>
      <hr class="divider">
      <div class="notice">
        If you did not request this code, you can safely ignore this email.
      </div>"""
    html = _shell(subject, inner)
    plain = (
        f"Your new SecuredVault verification code is: {otp_code}\n\n"
        f"This code expires in 10 minutes."
    )
    return subject, html, plain


def forgot_password_otp_email(otp_code: str) -> tuple[str, str, str]:
    """Return (subject, html, plain) for the forgot-password OTP."""
    subject = 'Password Reset OTP — SecuredVault'
    inner = f"""
      <h2>Password Reset</h2>
      <p class="lead">
        We received a request to reset your password.
        Use the code below to proceed. If you didn't request this,
        your account is still safe — just ignore this email.
      </p>
      <div class="otp-box">
        <div class="otp-code">{otp_code}</div>
        <div class="otp-expires">This code expires in 10 minutes</div>
      </div>
      <hr class="divider">
      <div class="notice">
        If you did not request a password reset, someone may have entered your email
        by mistake. No action is needed — your password has not been changed.
      </div>"""
    html = _shell(subject, inner, accent_color=_P['warning'])
    plain = (
        f"Your password reset code is: {otp_code}\n\n"
        f"This code expires in 10 minutes.\n"
        f"If you did not request this, no action is needed."
    )
    return subject, html, plain


def resend_forgot_otp_email(otp_code: str) -> tuple[str, str, str]:
    """Return (subject, html, plain) for a resent forgot-password OTP."""
    subject = 'New Password Reset Code — SecuredVault'
    inner = f"""
      <h2>New Password Reset Code</h2>
      <p class="lead">
        You requested a new password reset code.
        Please use the code below to reset your password.
      </p>
      <div class="otp-box">
        <div class="otp-code">{otp_code}</div>
        <div class="otp-expires">This code expires in 10 minutes</div>
      </div>
      <hr class="divider">
      <div class="notice">
        If you did not request this, you can safely ignore this email.
      </div>"""
    html = _shell(subject, inner, accent_color=_P['warning'])
    plain = (
        f"Your new password reset code is: {otp_code}\n\n"
        f"This code expires in 10 minutes."
    )
    return subject, html, plain


def security_alert_email(title: str, rule_name: str, threat_level: str, details: dict, blocked_until: str = None) -> tuple[str, str, str]:
    """Return (subject, html, plain) for a security or new device alert."""
    subject = f"Security Alert: {title} — SecuredVault"
    
    accent = _P['warning']
    if threat_level in ['HIGH', 'CRITICAL']:
        accent = _P['danger']
    elif threat_level == 'LOW':
        accent = _P['brand']

    # Build the details table
    details_html = ""
    plain_details = ""
    
    # Format details safely
    if details:
        # Extract verify_url specifically for New Device Login
        verify_url = details.get('verify_url')
        
        details_html += '<table class="dtable">'
        for k, v in details.items():
            if k == 'verify_url': continue # Handled as a button below
            key_name = str(k).replace('_', ' ').title()
            details_html += _row(key_name, str(v))
            plain_details += f"{key_name}: {v}\n"
        
        if blocked_until:
            details_html += _row("Blocked Until", str(blocked_until))
            plain_details += f"Blocked Until: {blocked_until}\n"
            
        details_html += '</table>'
    else:
        if blocked_until:
            details_html = f'<table class="dtable">{_row("Blocked Until", str(blocked_until))}</table>'
            plain_details = f"Blocked Until: {blocked_until}\n"

    verify_btn = ""
    plain_verify = ""
    if details and 'verify_url' in details:
        verify_btn = _btn("Verify This Device", details['verify_url'])
        plain_verify = f"\nTo verify this device, click here: {details['verify_url']}\n"
        
        # Override the notice for verification emails
        notice = """
        <div class="notice">
            If you do not recognize this device, your credentials may have been compromised. 
            Please change your password immediately.
        </div>"""
    else:
        notice = """
        <div class="notice">
            If this was you, you can safely ignore this email. If you don't recognize this activity, 
            please secure your account immediately.
        </div>"""

    inner = f"""
      <h2>{title}</h2>
      <p class="lead">
        We detected a <strong>{rule_name.replace('_', ' ').title()}</strong> event 
        associated with your SecuredVault account.
      </p>
      {details_html}
      {verify_btn}
      <hr class="divider">
      {notice}"""
      
    html = _shell(subject, inner, accent_color=accent)
    
    plain = (
        f"Security Alert: {title}\n\n"
        f"We detected a {rule_name.replace('_', ' ').title()} event.\n"
        f"Threat Level: {threat_level}\n\n"
        f"Details:\n{plain_details}"
        f"{plain_verify}\n"
        f"If you don't recognize this activity, please secure your account immediately."
    )
    
    return subject, html, plain


def device_verification_success_html() -> str:
    """Return a full HTML page for the 'device verified' browser response."""
    year = timezone.now().year
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Device Verified — SecuredVault</title>
<style>
  *,*::before,*::after{{box-sizing:border-box;margin:0;padding:0}}
  body{{font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;
        background:{_P['bg']};color:{_P['text']};
        display:flex;align-items:center;justify-content:center;
        min-height:100vh;padding:20px}}
  .card{{max-width:480px;width:100%;background:{_P['card']};
         border-radius:16px;box-shadow:0 8px 32px rgba(0,0,0,0.3);
         overflow:hidden;text-align:center;border:1px solid {_P['border']}}}
  .card-header{{background:linear-gradient(135deg,{_P['navy']},{_P['navy_light']});
                padding:36px 24px;border-bottom:1px solid {_P['border']}}}
  .icon{{font-size:48px;margin-bottom:12px}}
  .card-header h1{{background:linear-gradient(135deg,{_P['success']},#6EE7B7);
                    -webkit-background-clip:text;-webkit-text-fill-color:transparent;
                    background-clip:text;font-size:22px;font-weight:800}}
  .card-body{{padding:32px 24px}}
  .card-body p{{font-size:14px;color:{_P['muted']};line-height:1.7;margin-bottom:16px}}
  .check-list{{text-align:left;margin:20px 0;padding:0;list-style:none}}
  .check-list li{{font-size:14px;color:{_P['text']};padding:10px 0;
                   border-bottom:1px solid {_P['border']}}}
  .check-list li:last-child{{border-bottom:none}}
  .check-list li::before{{content:'✓ ';color:{_P['success']};font-weight:700;font-size:16px}}
  .close-msg{{background:{_P['navy']};border-radius:8px;padding:14px 18px;
               font-size:13px;color:{_P['brand']};margin-top:8px;
               border:1px solid {_P['border']}}}
  .card-footer{{padding:16px 24px;background:{_P['navy']};
                 border-top:1px solid {_P['border']}}}
  .card-footer p{{font-size:12px;color:{_P['muted']}}}
</style>
</head>
<body>
<div class="card">
  <div class="card-header">
    <div class="icon">✅</div>
    <h1>Device Verified Successfully</h1>
  </div>
  <div class="card-body">
    <p>Your device has been successfully verified and linked to your SecuredVault account.</p>
    <ul class="check-list">
      <li>Device identity confirmed</li>
      <li>Linked to your account</li>
      <li>Future logins from this device will be trusted</li>
    </ul>
    <div class="close-msg">You can safely close this page and return to the app.</div>
  </div>
  <div class="card-footer">
    <p>&copy; {year} SecuredVault. All rights reserved.</p>
  </div>
</div>
</body>
</html>"""


def device_verification_error_html(message: str, is_expired: bool = False) -> str:
    """Return a full HTML page for device verification errors."""
    year = timezone.now().year
    icon = '⏰' if is_expired else '❌'
    title = 'Link Expired' if is_expired else 'Verification Failed'
    accent = _P['warning'] if is_expired else _P['danger']

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} — SecuredVault</title>
<style>
  *,*::before,*::after{{box-sizing:border-box;margin:0;padding:0}}
  body{{font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;
        background:{_P['bg']};color:{_P['text']};
        display:flex;align-items:center;justify-content:center;
        min-height:100vh;padding:20px}}
  .card{{max-width:480px;width:100%;background:{_P['card']};
         border-radius:16px;box-shadow:0 8px 32px rgba(0,0,0,0.3);
         overflow:hidden;text-align:center;border:1px solid {_P['border']}}}
  .card-header{{background:linear-gradient(135deg,{_P['navy']},{_P['navy_light']});
                padding:36px 24px;border-bottom:1px solid {_P['border']}}}
  .icon{{font-size:48px;margin-bottom:12px}}
  .card-header h1{{color:{accent};font-size:22px;font-weight:800}}
  .card-body{{padding:32px 24px}}
  .card-body p{{font-size:14px;color:{_P['muted']};line-height:1.7;margin-bottom:16px}}
  .msg-box{{background:{_P['navy']};border-radius:8px;padding:16px;
             font-size:14px;color:{_P['text']};margin:16px 0;
             border-left:4px solid {accent};border:1px solid {_P['border']};
             border-left:4px solid {accent}}}
  .card-footer{{padding:16px 24px;background:{_P['navy']};
                 border-top:1px solid {_P['border']}}}
  .card-footer p{{font-size:12px;color:{_P['muted']}}}
</style>
</head>
<body>
<div class="card">
  <div class="card-header">
    <div class="icon">{icon}</div>
    <h1>{title}</h1>
  </div>
  <div class="card-body">
    <div class="msg-box">{message}</div>
    <p>Please try logging in again from your app to receive a new verification link.</p>
  </div>
  <div class="card-footer">
    <p>&copy; {year} SecuredVault. All rights reserved.</p>
  </div>
</div>
</body>
</html>"""
