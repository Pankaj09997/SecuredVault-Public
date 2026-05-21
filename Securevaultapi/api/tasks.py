from celery import shared_task
import logging
import requests
from django.conf import settings
from django.utils import timezone
from datetime import timedelta
from geopy.distance import geodesic
from  api.security_config import THREAT_DETECTION_CONFIG
from api.models import SuspiciousActivityLog, UserLocation, SecurityNotification, MyUser, DeviceVerification
from api.security_actions import apply_security_rule

logger = logging.getLogger(__name__)

def send_resend_email(subject, message, from_email, recipient_list, html_message=None, html_body=None, plain_body=None):
    if not settings.RESEND_API_KEY:
        logger.error("RESEND_API_KEY is missing in this process")
        raise RuntimeError("Resend API key is missing")

    payload = {
        'from': from_email or settings.DEFAULT_FROM_EMAIL,
        'to': recipient_list,
        'subject': subject,
    }
    html_content = html_body or html_message
    text_content = plain_body or message
    if html_content:
        payload['html'] = html_content
    if text_content:
        payload['text'] = text_content

    response = requests.post(
        settings.RESEND_API_URL,
        headers={
            'Authorization': f'Bearer {settings.RESEND_API_KEY}',
            'Content-Type': 'application/json',
        },
        json=payload,
        timeout=15,
    )
    if response.status_code >= 400:
        logger.error("Resend email API failed with status %s: %s", response.status_code, response.text)
        response.raise_for_status()

    logger.info("Email sent successfully via Resend to %s: %s", recipient_list, subject)
    return response.json()

@shared_task
def send_async_email(subject, message, from_email, recipient_list, html_message=None, html_body=None, plain_body=None):
    """Send email asynchronously using Celery.
    
    Supports two calling conventions:
    1. Plain text: send_async_email(subject, message, from_email, recipient_list)
    2. HTML+plain: send_async_email(subject, html_body=..., plain_body=..., from_email=..., recipient_list=...)
    """
    from django.core.mail import EmailMultiAlternatives, send_mail as django_send_mail
    if settings.EMAIL_PROVIDER == 'resend':
        return send_resend_email(
            subject=subject,
            message=message,
            from_email=from_email,
            recipient_list=recipient_list,
            html_message=html_message,
            html_body=html_body,
            plain_body=plain_body,
        )

    if not settings.EMAIL_HOST_USER or not settings.EMAIL_HOST_PASSWORD:
        logger.error(
            "Email settings are missing in this process. EMAIL_HOST_USER set=%s, EMAIL_HOST_PASSWORD set=%s",
            bool(settings.EMAIL_HOST_USER),
            bool(settings.EMAIL_HOST_PASSWORD),
        )
        raise RuntimeError("Email SMTP settings are missing")

    try:
        # If html_body is provided, send multipart (HTML + plain text)
        if html_body:
            msg = EmailMultiAlternatives(
                subject=subject,
                body=plain_body or message or '',
                from_email=from_email,
                to=recipient_list,
            )
            msg.attach_alternative(html_body, "text/html")
            msg.send(fail_silently=False)
        else:
            django_send_mail(
                subject=subject,
                message=message or '',
                from_email=from_email,
                recipient_list=recipient_list,
                fail_silently=False,
                html_message=html_message,
            )
        logger.info(f"Email sent successfully to {recipient_list}: {subject}")
    except Exception as e:
        logger.error(f"Failed to send email to {recipient_list}: {str(e)}", exc_info=True)
        raise

@shared_task
def update_geolocation_async(user_id, ip_address, request_timestamp=None):
    """Update user location asynchronously with rapid location change detection."""
    try:
        user = MyUser.objects.get(id=user_id)
        
        current_time = timezone.now() if request_timestamp is None else timezone.datetime.fromtimestamp(request_timestamp, tz=timezone.get_current_timezone())
        
        existing_locations = UserLocation.objects.filter(user=user).exclude(latitude=None, longitude=None).order_by('-last_seen')
        
        current_geo = get_geo_data(ip_address)
        
        if existing_locations:
            last_location = existing_locations.first()
            time_diff = (current_time - last_location.last_seen).total_seconds() / 60.0
            
            if current_geo.get('latitude') is not None and current_geo.get('longitude') is not None:
                distance = geodesic(
                    (current_geo['latitude'], current_geo['longitude']),
                    (last_location.latitude, last_location.longitude)
                ).km
                
                threat_levels = {'CRITICAL': 4, 'HIGH': 3, 'MEDIUM': 2, 'LOW': 1}
                rules = [
                    ('IMPOSSIBLE_TRAVEL', THREAT_DETECTION_CONFIG.get('IMPOSSIBLE_TRAVEL', {})),
                    ('RAPID_LOCATION_CHANGE', THREAT_DETECTION_CONFIG.get('RAPID_LOCATION_CHANGE', {}))
                ]
                rules.sort(key=lambda x: threat_levels.get(x[1].get('threat_level', 'LOW'), 1), reverse=True)
                
                for rule, config in rules:
                    if (
                        config and
                        distance > config.get('max_distance_km', float('inf')) and
                        time_diff < config.get('time_window_minutes', float('inf'))
                    ):
                        context = {
                            'from_location': f"{last_location.city}, {last_location.country}",
                            'to_location': f"{current_geo.get('city', 'Unknown')}, {current_geo.get('country', 'Unknown')}",
                            'from_latitude': last_location.latitude,
                            'from_longitude': last_location.longitude,
                            'to_latitude': current_geo.get('latitude'),
                            'to_longitude': current_geo.get('longitude'),
                            'distance': round(distance, 2),
                            'time_elapsed': round(time_diff, 2),
                            'ip': ip_address,
                            'time': current_time.isoformat(),
                            'blocked_until': (current_time + timedelta(minutes=config.get('block_duration_minutes', 120))).isoformat() if config.get('should_block', False) else None
                        }
                        
                        current_location, _ = UserLocation.objects.update_or_create(
                            user=user,
                            ip_address=ip_address,
                            defaults={
                                **current_geo,
                                'last_seen': current_time
                            }
                        )
                        apply_security_rule(
                            user=user,
                            rule_name=rule,
                            activity_type=rule.lower(),
                            ip_address=ip_address,
                            location=current_location,
                            device=user.current_device,
                            details=context,
                            reason=f"{rule} detected",
                        )

                        break  # Stop after the highest severity rule is matched

        UserLocation.objects.update_or_create(
            user_id=user_id,
            ip_address=ip_address,
            defaults={
                **current_geo,
                'last_seen': current_time
            }
        )
        
    except MyUser.DoesNotExist:
        logger.error(f"User with ID {user_id} does not exist")
    except Exception as e:
        logger.error(f"Geolocation update failed for user {user_id}, IP {ip_address}: {str(e)}")

def get_geo_data(ip_address):
    """Get real geo data from IP with mock data for testing."""
    mock_data = {
        '127.0.0.1': {
            'country': 'Local', 'region': 'Development', 'city': 'Localhost',
            'latitude': None, 'longitude': None, 'isp': 'Local Network', 'timezone': settings.TIME_ZONE
        },
        '::1': {
            'country': 'Local', 'region': 'Development', 'city': 'Localhost',
            'latitude': None, 'longitude': None, 'isp': 'Local Network', 'timezone': settings.TIME_ZONE
        },
        '202.70.82.34': {
            'country': 'Nepal', 'region': 'Bagmati Province', 'city': 'Kathmandu',
            'latitude': 27.7017, 'longitude': 85.3206, 'isp': 'Nepal Telecommunications Corporation', 'timezone': 'Asia/Kathmandu'
        },
    }
    import ipaddress
    
    if ip_address in mock_data:
        logger.info(f"Using mock geo data for {ip_address}: {mock_data[ip_address]}")
        return mock_data[ip_address]
        
    try:
        if ipaddress.ip_address(ip_address).is_private:
            logger.info(f"Skipping geo API for private IP: {ip_address}")
            return {
                'country': 'Local', 'region': 'Local', 'city': 'Local',
                'latitude': None, 'longitude': None, 'isp': 'Local Network', 'timezone': settings.TIME_ZONE
            }
    except ValueError:
        pass
    
    try:
        response = requests.get(f"http://ip-api.com/json/{ip_address}", timeout=3)
        response.raise_for_status()
        data = response.json()
        logger.info(f"API response for {ip_address}: {data}")
        
        if data.get('status') == 'success':
            return {
                'country': data.get('country', 'Unknown'),
                'region': data.get('regionName', 'Unknown'),
                'city': data.get('city', 'Unknown'),
                'latitude': data.get('lat'),
                'longitude': data.get('lon'),
                'isp': data.get('isp', 'Unknown'),
                'timezone': data.get('timezone', settings.TIME_ZONE),
            }
    except requests.RequestException as e:
        logger.warning(f"Geolocation API request failed for {ip_address}: {str(e)}")
    
    return {
        'country': 'Unknown',
        'region': 'Unknown',
        'city': 'Unknown',
        'latitude': None,
        'longitude': None,
        'isp': 'Unknown',
        'timezone': settings.TIME_ZONE
    }

@shared_task
def send_security_notification(user_id, notification_type, context):
    """Send security notification asynchronously with database-based rate-limiting."""
    try:
        user = MyUser.objects.get(id=user_id)
        # Use settings.NOTIFICATION_SETTINGS with fallback
        config = getattr(settings, 'NOTIFICATION_SETTINGS', {}).get(notification_type, {'email_cooldown_minutes': 15})
        cooldown_minutes = config.get('email_cooldown_minutes', 15)

        # Database-based rate-limiting
        recent_notification = SecurityNotification.objects.filter(
            user=user,
            notification_type=notification_type,
            email_sent_at__gte=timezone.now() - timedelta(minutes=cooldown_minutes)
        ).exists()
        if recent_notification:
            return

        subject = f"Security Alert: {notification_type.replace('_', ' ').title()}"
        message = generate_notification_message(notification_type, context)

        send_async_email.delay(
            subject=subject,
            message=message,
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email]
        )

        SecurityNotification.objects.create(
            user=user,
            notification_type=notification_type,
            title=subject,
            message=message,
            email_sent=True,
            email_sent_at=timezone.now()
        )
    except Exception as e:
        logger.error(f"Failed to send security notification to user {user_id}: {str(e)}")

def generate_notification_message(notification_type, context):
    """Generate notification message based on type."""
    templates = {
        'new_device': (
            f"New sign-in detected from a device we don't recognize:\n\n"
            f"• Device: {context.get('device', 'Unknown')}\n"
            f"• Location: {context.get('location', 'Unknown')}\n"
            f"• IP Address: {context.get('ip', 'Unknown')}\n"
            f"• Time: {context.get('time', 'Unknown')}\n\n"
            f"If this was you, please verify this device: {context.get('verify_url', '')}\n"
            f"If not, please secure your account immediately: {settings.BASE_URL}/security"
        ),
        'impossible_travel': (
            f"Impossible travel detected on your account:\n\n"
            f"• From: {context.get('from_location', 'Unknown location')}\n"
            f"• To: {context.get('to_location', 'Unknown location')}\n"
            f"• Distance: {round(context.get('distance', 0), 2)} km\n"
            f"• Time elapsed: {round(context.get('time_elapsed', 0), 2)} minutes\n\n"
            f"Your account has been temporarily locked as a security precaution."
        ),
        'rapid_location_change': (
            f"Rapid location change detected on your account:\n\n"
            f"• From: {context.get('from_location', 'Unknown location')}\n"
            f"• To: {context.get('to_location', 'Unknown location')}\n"
            f"• Distance: {round(context.get('distance', 0), 2)} km\n"
            f"• Time elapsed: {round(context.get('time_elapsed', 0), 2)} minutes\n\n"
            f"Please verify if this was you: {settings.BASE_URL}/security"
        ),
        'multiple_device_access': (
            f"Multiple device access detected:\n\n"
            f"• Devices used: {context.get('device_count', 0)}\n"
            f"• Time window: {context.get('time_window', 0)} minutes\n\n"
            f"Please review your account security: {settings.BASE_URL}/security"
        ),
        'file_access': (
            f"File access detected:\n\n"
            f"• Action: {context.get('action', 'Unknown')}\n"
            f"• File: {context.get('file_name', 'Unknown')}\n"
            f"• Location: {context.get('location', 'Unknown')}\n"
            f"• IP Address: {context.get('ip', 'Unknown')}\n"
            f"• Time: {context.get('time', 'Unknown')}\n\n"
            f"Please review your account security: {settings.BASE_URL}/security"
        ),
        'password_change_otp': (
            f"You requested to change your password.\n\n"
            f"Your One-Time Password (OTP) is: {context.get('otp', '')}\n\n"
            f"If you did not request this, please secure your account immediately: {settings.BASE_URL}/security"
        ),
        'password_changed': (
            f"Your account password was successfully changed.\n\n"
            f"• Device: {context.get('device', 'Unknown')}\n"
            f"• IP Address: {context.get('ip', 'Unknown')}\n"
            f"• Time: {context.get('time', 'Unknown')}\n\n"
            f"If you did not perform this action, contact support immediately."
        ),
        'default': (
            f"Suspicious activity detected on your account.\n"
            f"Please review your account security settings: {settings.BASE_URL}/security"
        )
    }
    return templates.get(notification_type, templates['default'])

@shared_task
def cleanup_expired_verifications():
    """Remove expired device verifications."""
    try:
        DeviceVerification.objects.filter(expires_at__lt=timezone.now()).delete()
    except Exception as e:
        logger.error(f"Error cleaning up expired verifications: {str(e)}")
