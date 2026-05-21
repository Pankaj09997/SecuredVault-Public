import logging
from datetime import timedelta

from django.conf import settings
from django.core.cache import cache
from django.utils import timezone

from api.models import SecurityNotification, SuspiciousActivityLog
from api.security_config import NOTIFICATION_SETTINGS, THREAT_DETECTION_CONFIG

logger = logging.getLogger(__name__)


NOTIFICATION_TYPE_BY_RULE = {
    'NEW_DEVICE_LOGIN': 'new_device',
    'RAPID_LOCATION_CHANGE': 'location_change',
    'IMPOSSIBLE_TRAVEL': 'account_locked',
    'FAILED_LOGIN_ATTEMPTS': 'account_locked',
    'UNUSUAL_ACCESS_HOURS': 'unusual_access',
    'UNUSUAL_FILE_ACCESS': 'unusual_access',
    'BULK_FILE_ACCESS': 'suspicious_activity',
    'MULTIPLE_DEVICE_ACCESS': 'suspicious_activity',
}


def get_rule_config(rule_name):
    return THREAT_DETECTION_CONFIG.get(rule_name, {})


def get_action_from_config(config):
    if config.get('should_block', False):
        return 'blocked'
    if config.get('should_notify', False):
        return 'notified'
    return 'logged'


def temporarily_block_user(user, duration_minutes, reason):
    blocked_until = timezone.now() + timedelta(minutes=duration_minutes)
    user.is_temporarily_blocked = True
    user.blocked_until = blocked_until
    user.blocked_reason = reason
    user.save(update_fields=[
        'is_temporarily_blocked',
        'blocked_until',
        'blocked_reason',
    ])
    cache.set(f'user_blocked_{user.id}', True, duration_minutes * 60)
    return blocked_until


def clear_expired_user_block(user):
    if user.blocked_until and user.blocked_until <= timezone.now():
        user.is_temporarily_blocked = False
        user.blocked_until = None
        user.blocked_reason = None
        user.save(update_fields=[
            'is_temporarily_blocked',
            'blocked_until',
            'blocked_reason',
        ])
        cache.delete(f'user_blocked_{user.id}')
        return True
    return False


def create_security_notification(user, rule_name, activity, config, details, blocked_until=None):
    notification_type = NOTIFICATION_TYPE_BY_RULE.get(rule_name, 'suspicious_activity')
    title = rule_name.replace('_', ' ').title()
    if config.get('should_block', False):
        title = 'Account temporarily blocked'

    message_parts = [
        f"Security rule triggered: {rule_name.replace('_', ' ').title()}",
        f"Threat level: {config.get('threat_level', 'LOW')}",
    ]
    if blocked_until:
        message_parts.append(f"Blocked until: {blocked_until}")
    if details:
        message_parts.append(f"Details: {details}")

    notification = SecurityNotification.objects.create(
        user=user,
        notification_type=notification_type,
        title=title,
        message='\n'.join(message_parts),
        suspicious_activity=activity,
        email_sent=False,
    )

    cooldown_key = f"notify_cooldown_{user.id}_{notification_type}"
    cooldown_active = cache.get(cooldown_key)
    logger.warning(
        "NOTIFICATION CHECK: user=%s type=%s cooldown_key=%s cooldown_active=%s",
        user.id, notification_type, cooldown_key, cooldown_active,
    )

    if not cooldown_active:
        try:
            from api.tasks import send_async_email
            from api.email_templates import security_alert_email
            
            logger.warning(
                "DISPATCHING EMAIL TASK: subject=%s to=%s from=%s",
                title, user.email, settings.DEFAULT_FROM_EMAIL,
            )
            
            subject, html_body, plain_body = security_alert_email(
                title=title,
                rule_name=rule_name,
                threat_level=config.get('threat_level', 'LOW'),
                details=details,
                blocked_until=blocked_until.isoformat() if blocked_until else None
            )
            
            email_kwargs = {
                'subject': subject,
                'message': plain_body,
                'from_email': settings.DEFAULT_FROM_EMAIL,
                'recipient_list': [user.email],
                'html_body': html_body,
                'plain_body': plain_body,
            }
            
            if getattr(settings, 'SEND_EMAILS_ASYNC', True):
                send_async_email.delay(**email_kwargs)
                logger.warning("EMAIL TASK DISPATCHED SUCCESSFULLY for user %s", user.id)
            else:
                send_async_email(**email_kwargs)
                logger.warning("EMAIL SENT SYNCHRONOUSLY for user %s", user.id)
            notification.email_sent = True
            notification.email_sent_at = timezone.now()
            notification.save(update_fields=['email_sent', 'email_sent_at'])
            cache.set(
                cooldown_key,
                True,
                NOTIFICATION_SETTINGS.get('email_cooldown_minutes', 15) * 60,
            )
        except Exception as exc:
            logger.error("FAILED TO DISPATCH email task: %s", exc, exc_info=True)
    else:
        logger.warning("SKIPPING EMAIL: cooldown active for key %s", cooldown_key)

    return notification


def apply_security_rule(
    *,
    user,
    rule_name,
    activity_type,
    ip_address=None,
    location=None,
    device=None,
    details=None,
    risk_score=0,
    reason=None,
):
    """Apply configured log/notify/block actions for one security rule."""
    config = get_rule_config(rule_name)
    if config.get('enabled', True) is False:
        return None

    details = details or {}
    action_taken = get_action_from_config(config)
    blocked_until = None

    if config.get('should_block', False):
        blocked_until = temporarily_block_user(
            user=user,
            duration_minutes=config.get('block_duration_minutes', 30),
            reason=reason or f"{rule_name.replace('_', ' ').title()} detected",
        )
        details['blocked_until'] = blocked_until.isoformat()

    activity = None
    if config.get('should_log', True):
        activity = SuspiciousActivityLog.objects.create(
            user=user,
            activity_type=activity_type,
            threat_level=config.get('threat_level', 'LOW'),
            ip_address=ip_address,
            location=location,
            device=device,
            details=details,
            risk_score=risk_score,
            action_taken=action_taken,
            email_sent=False,
            user_blocked=config.get('should_block', False),
        )

    if config.get('should_notify', False):
        notification = create_security_notification(
            user=user,
            rule_name=rule_name,
            activity=activity,
            config=config,
            details=details,
            blocked_until=blocked_until,
        )
        if activity is not None and notification.email_sent:
            activity.email_sent = True
            activity.save(update_fields=['email_sent'])

    logger.info(
        "Applied security rule %s for user %s with action %s",
        rule_name,
        user.id,
        action_taken,
    )
    return activity
