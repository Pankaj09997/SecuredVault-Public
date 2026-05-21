from django.utils import timezone
from django.contrib.auth.models import AnonymousUser
from django.core.cache import cache
from django.http import JsonResponse
from django.core.mail import send_mail
from django.conf import settings
from geopy.distance import geodesic
import requests
import logging
import hashlib
import json
from datetime import datetime, time, timedelta
import pytz
from api.models import UserLocation, SuspiciousActivityLog, DeviceInfo
from api.security_config import THREAT_DETECTION_CONFIG, RISK_SCORING_WEIGHTS, NOTIFICATION_SETTINGS
from api.security_actions import apply_security_rule, clear_expired_user_block
from rest_framework_simplejwt.authentication import JWTAuthentication

logger = logging.getLogger(__name__)

# get the client ip address
def get_client_ip(request):
    """Get client IP address with proxy support"""
    # 1. Check if the mobile app explicitly sent its public IP (for local testing)
    custom_public_ip = request.META.get('HTTP_X_PUBLIC_IP')
    if custom_public_ip:
        return custom_public_ip.strip()

    # 2. Check standard proxy headers
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        return x_forwarded_for.split(',')[0].strip()

    # 3. Fallback to the direct connection IP
    return request.META.get('REMOTE_ADDR')

# this is used to create the blueprint for the device so that we could create the device which will be uniquely known by the user
def generate_device_fingerprint(request):
    """Create a sophisticated device fingerprint"""
    fingerprint_data = {
        # like user device info,browser info
        'user_agent': request.META.get('HTTP_USER_AGENT', ''),
        # Indicates the language preferences of the browser.
        'accept_language': request.META.get('HTTP_ACCEPT_LANGUAGE', ''),
        # Lists which compression algorithms (like gzip, br) the browser supports.
        'accept_encoding': request.META.get('HTTP_ACCEPT_ENCODING', ''),
        # screen resoulution
        'screen_resolution': request.GET.get('screen_res', ''),
        # timezone we are currently in 
        'timezone_offset': request.GET.get('tz_offset', ''),
    }
    fingerprint_str = json.dumps(fingerprint_data, sort_keys=True)
    return hashlib.sha256(fingerprint_str.encode()).hexdigest()

def log_suspicious_activity(user, activity_type, threat_level, request, details):
    """Log suspicious activity with rate limiting"""
    cache_key = f"activity_log_{user.id}_{activity_type}"
    if cache.get(cache_key):
        return  # Skip if recently logged

    try:
        SuspiciousActivityLog.objects.create(
            user=user,
            activity_type=activity_type,
            threat_level=threat_level,
            ip_address=get_client_ip(request) if request else None,
            details=details,
            action_taken='logged'
        )
        cache.set(cache_key, True, 300)  # Prevent duplicates for 5 minutes
    except Exception as e:
        logger.error(f"Failed to log suspicious activity: {str(e)}")

def send_security_notification(user, notification_type, context):
    """Send security notification with rate limiting"""
    cooldown_key = f"notify_cooldown_{user.id}_{notification_type}"
    if cache.get(cooldown_key):
        return
        
    try:
        subject = f"Security Alert: {notification_type.replace('_', ' ').title()}"
        message = generate_notification_message(notification_type, context)
        
        send_mail(
            subject=subject,
            message=message,
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=True,
        )
        
        # Set cooldown period
        cache.set(
            cooldown_key,
            True,
            NOTIFICATION_SETTINGS.get('email_cooldown_minutes', 15) * 60
        )
    except Exception as e:
        logger.error(f"Failed to send security notification: {str(e)}")

def generate_notification_message(notification_type, context):
    """Generate notification message based on type"""
    templates = {
        'new_device': (
            f"New sign-in detected from a device we don't recognize:\n\n"
            f"• Device: {context.get('device', 'Unknown')}\n"
            f"• IP Address: {context.get('ip', 'Unknown')}\n"
            f"• Time: {context.get('time', 'Unknown')}\n\n"
            f"If this was you, you can ignore this alert. "
            f"If not, please secure your account immediately."
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
            f"Please verify if this was you."
        ),
        'multiple_device_access': (
            f"Multiple device access detected:\n\n"
            f"• Devices used: {context.get('device_count', 0)}\n"
            f"• Time window: {context.get('time_window', 0)} minutes\n\n"
            f"Please review your account security."
        ),
        'default': (
            f"Suspicious activity detected on your account. "
            f"Please review your account security settings."
        )
    }
    return templates.get(notification_type, templates['default'])

def temporarily_block_user(user, duration_minutes, reason):
    """Block user account temporarily"""
    try:
        user.is_temporarily_blocked = True
        user.blocked_until = timezone.now() + timedelta(minutes=duration_minutes)
        user.blocked_reason = reason
        user.save(update_fields=[
            'is_temporarily_blocked',
            'blocked_until',
            'blocked_reason'
        ])
        cache.set(f"user_blocked_{user.id}", True, duration_minutes * 60)
    except Exception as e:
        logger.error(f"Failed to block user {user.id}: {str(e)}")

def _resolve_user_timezone(user):
    """Resolve the user's real timezone from their most recent geolocation record.
    
    Falls back to settings.TIME_ZONE only if no location has been recorded yet.
    This ensures the unusual-hours check uses the user's local time (e.g. Asia/Kathmandu)
    instead of the server's UTC clock.
    """
    try:
        latest_location = UserLocation.objects.filter(
            user=user,
            timezone__isnull=False,
        ).exclude(timezone='').order_by('-last_seen').first()
        if latest_location and latest_location.timezone:
            return latest_location.timezone
    except Exception:
        pass
    return settings.TIME_ZONE


def is_access_time_allowed(request):
    """Check if current time is within allowed access hours using the user's LOCAL timezone."""
    config = THREAT_DETECTION_CONFIG.get('UNUSUAL_ACCESS_HOURS', {})
    if not config.get('should_block', False):
        return True
    
    # Resolve the user's real timezone from their geolocation data
    user_timezone = _resolve_user_timezone(request.user)
    try:
        tz = pytz.timezone(user_timezone)
    except pytz.UnknownTimeZoneError:
        logger.warning(f"Unknown timezone '{user_timezone}' for user {request.user.email}, falling back to server TZ")
        tz = pytz.timezone(settings.TIME_ZONE)
    
    # Get current time in user's LOCAL timezone
    user_now = timezone.now().astimezone(tz)
    current_hour = user_now.hour
    start_hour = config.get('start_hour', 23)
    end_hour = config.get('end_hour', 5)
    
    # Check if current time is within restricted hours
    # Handles overnight ranges (e.g. 23:00 → 05:00) correctly
    is_restricted = (
        (current_hour >= start_hour or current_hour < end_hour) 
        if start_hour > end_hour else 
        (start_hour <= current_hour < end_hour)
    )
    
    if is_restricted:
        apply_security_rule(
            user=request.user,
            rule_name='UNUSUAL_ACCESS_HOURS',
            activity_type='unusual_time_access',
            ip_address=get_client_ip(request),
            details={
                'access_time': str(user_now),
                'timezone': user_timezone,
                'local_hour': current_hour,
                'restricted_hours': f"{start_hour}:00 - {end_hour}:00",
            }
        )
        return False
    
    return True

# Security Middleware
class SecurityMiddleware:
    """Comprehensive security middleware with threat detection"""
    
    def __init__(self, get_response):
        self.get_response = get_response
        self.geolocation_service_url = "http://ip-api.com/json/"
        self.geolocation_timeout = 5
        
    def __call__(self, request):
        # Skip security checks for specific paths
        if self._should_skip_checks(request):
            return self.get_response(request)
            
        # Try to authenticate with JWT if not already authenticated
        if not request.user.is_authenticated:
            try:
                jwt_auth = JWTAuthentication()
                auth_result = jwt_auth.authenticate(request)
                if auth_result:
                    request.user, request.auth = auth_result
            except Exception:
                pass
                
        # Pre-request security checks
        if request.user.is_authenticated:
            # Check account lock status
            if self._is_user_security_blocked(request.user):
                return self._security_block_response(request.user)
            
            # Check time-based access
            if not is_access_time_allowed(request):
                return self._security_block_response(request.user)
        
        response = self.get_response(request)
        
        # Post-request security tracking
        if request.user.is_authenticated:
            try:
                self._track_and_analyze_activity(request)
            except Exception as e:
                logger.error(f"Security tracking error: {str(e)}", exc_info=True)
        
        return response
    
    def _should_skip_checks(self, request):
        """Skip security checks for specific paths"""
        skip_paths = ['/health/', '/status/', '/static/', '/media/']
        return any(request.path.startswith(path) for path in skip_paths)
    
    def _security_block_response(self, user):
        """Response for blocked users"""
        if user.blocked_until:
            time_left = user.blocked_until - timezone.now()
            minutes_left = max(0, time_left.total_seconds() // 60)
            return JsonResponse(
                {
                    'msg': 'Account temporarily blocked',
                    'minutes_left': int(minutes_left),
                    'blocked_until': user.blocked_until.isoformat(),
                    'reason': user.blocked_reason or 'Security policy violation',
                },
                status=403,
            )
        return JsonResponse(
            {
                'msg': 'Account locked due to security concerns',
                'reason': user.blocked_reason or 'Security policy violation',
            },
            status=403,
        )
    
    def _is_user_security_blocked(self, user):
        """Check if user is blocked with caching"""
        if clear_expired_user_block(user):
            return False

        cache_key = f"user_blocked_{user.id}"
        try:
          blocked_status = cache.get(cache_key)
        except Exception:
          blocked_status = False  

        
        if blocked_status is None:
            blocked_status = user.is_temporarily_blocked_active() or user.is_account_locked()
            cache.set(cache_key, blocked_status, 60)  # Cache for 1 minute
        
        return blocked_status
    
    def _track_and_analyze_activity(self, request):
        """Track and analyze user activity"""
        user = request.user
        ip_address = get_client_ip(request)
        current_device = request.user.current_device
        device_fingerprint = generate_device_fingerprint(request)
        geo_data = self._get_geolocation_data(ip_address)
        
        # Track location and device
        location = self._update_user_location(user, ip_address, geo_data)
        device = self._update_user_device(user, device_fingerprint, request)
        
        # Run security checks
        self._check_location_anomalies(user, location)
        self._check_device_anomalies(user, current_device)
        self._check_session_anomalies(request, user)
        
        # Update risk profile
        self._update_user_risk_profile(user)
    
    def _get_geolocation_data(self, ip_address):
        """Get geolocation data with caching"""
        import ipaddress as _ipaddress
        
        # Skip geo lookup for loopback and private IPs
        if ip_address in ['127.0.0.1', '::1']:
            return {
                'country': 'Local',
                'region': 'Development',
                'city': 'Localhost',
                'latitude': None,
                'longitude': None,
                'isp': 'Local Network',
                'timezone': settings.TIME_ZONE,
            }
        
        try:
            if _ipaddress.ip_address(ip_address).is_private:
                logger.info(f"Skipping geo API for private IP: {ip_address}")
                return {
                    'country': 'Local',
                    'region': 'Local',
                    'city': 'Local',
                    'latitude': None,
                    'longitude': None,
                    'isp': 'Local Network',
                    'timezone': settings.TIME_ZONE,
                }
        except ValueError:
            pass
        
        cache_key = f"geo_{ip_address}"
        geo_data = cache.get(cache_key)
        
        if geo_data is not None:
            logger.info(f"Cached geo data for {ip_address}: {geo_data}")
            return geo_data
        
        try:
            response = requests.get(
                f"{self.geolocation_service_url}{ip_address}",
                timeout=self.geolocation_timeout
            )
            response.raise_for_status()
            data = response.json()
            logger.info(f"Geolocation API response for {ip_address}: {data}")
            
            if data.get('status') == 'success':
                geo_data = {
                    'country': data.get('country', 'Unknown'),
                    'region': data.get('regionName', 'Unknown'),
                    'city': data.get('city', 'Unknown'),
                    'latitude': data.get('lat'),
                    'longitude': data.get('lon'),
                    'isp': data.get('isp', 'Unknown'),
                    'timezone': data.get('timezone', settings.TIME_ZONE),
                }
                cache.set(cache_key, geo_data, 3600)  # Cache for 1 hour
                logger.info(f"Stored geo data for {ip_address}: {geo_data}")
                return geo_data
        except Exception as e:
            logger.error(f"Geolocation lookup failed for {ip_address}: {str(e)}")
        
        return {
            'country': 'Unknown',
            'region': 'Unknown',
            'city': 'Unknown',
            'latitude': None,
            'longitude': None,
            'isp': 'Unknown',
            'timezone': settings.TIME_ZONE,
        }
    
    def _update_user_location(self, user, ip_address, geo_data):
        """Update or create user location record"""
        location, created = UserLocation.objects.update_or_create(
            user=user,
            ip_address=ip_address,
            defaults={
                'country': geo_data['country'],
                'region': geo_data['region'],
                'city': geo_data['city'],
                'latitude': geo_data['latitude'],
                'longitude': geo_data['longitude'],
                'isp': geo_data['isp'],
                'timezone': geo_data['timezone'],
            }
        )
        
        if created:
            log_suspicious_activity(
                user=user,
                activity_type='new_location',
                threat_level='LOW',
                request=None,
                details={
                    'location': f"{geo_data['city']}, {geo_data['country']}",
                    'ip_address': ip_address,
                }
            )
        
        return location
    
    def _update_user_device(self, user, fingerprint, request):
        """Update or create user device record"""
        user_agent = request.META.get('HTTP_USER_AGENT', 'Unknown')
        
        device, created = DeviceInfo.objects.update_or_create(
            user=user,
            device_id=fingerprint,
            defaults={
                'user_agent': user_agent,
                'last_used': timezone.now(),
                'browser_info': request.META.get('HTTP_SEC_CH_UA', ''),
            }
        )
        
        if created:
            self._handle_new_device(user, device, request)
        
        return device
    
    def _handle_new_device(self, user, device, request):
        """Process new device detection"""
        config = THREAT_DETECTION_CONFIG.get('NEW_DEVICE_LOGIN', {})
        
        apply_security_rule(
            user=user,
            rule_name='NEW_DEVICE_LOGIN',
            activity_type='new_device',
            ip_address=get_client_ip(request),
            device=device,
            details={
                'device_info': str(device),
                'fingerprint': device.device_id,
            }
        )
    
    def _check_location_anomalies(self, user, current_location):
        """Check for suspicious location patterns"""
        self._detect_rapid_location_change(user, current_location)
        self._detect_impossible_travel(user, current_location)

    def _detect_rapid_location_change(self, user, current_location):
        """Detect rapid location changes and impossible travel with severity prioritization"""
        threat_levels = {'CRITICAL': 4, 'HIGH': 3, 'MEDIUM': 2, 'LOW': 1}
        rules = [
            ('IMPOSSIBLE_TRAVEL', THREAT_DETECTION_CONFIG.get('IMPOSSIBLE_TRAVEL', {})),
            ('RAPID_LOCATION_CHANGE', THREAT_DETECTION_CONFIG.get('RAPID_LOCATION_CHANGE', {}))
        ]
        rules.sort(key=lambda x: threat_levels.get(x[1].get('threat_level', 'LOW'), 1), reverse=True)
        
        recent_locations = UserLocation.objects.filter(
            user=user,
            last_seen__gte=timezone.now() - timedelta(minutes=60)
        ).exclude(pk=current_location.pk).order_by('-last_seen')[:5]
        
        for location in recent_locations:
            if current_location.latitude and current_location.longitude and location.latitude and location.longitude:
                point_a = (location.latitude, location.longitude)
                point_b = (current_location.latitude, current_location.longitude)
                distance = geodesic(point_a, point_b).kilometers
                time_diff = (current_location.last_seen - location.last_seen).total_seconds() / 60.0
                
                for rule_name, config in rules:
                    if not config.get('enabled', True):
                        continue
                    if (
                        distance > config.get('max_distance_km', float('inf')) and
                        time_diff <= config.get('time_window_minutes', float('inf'))
                    ):
                        self._handle_location_anomaly(
                            user=user,
                            current_location=current_location,
                            previous_location=location,
                            distance=distance,
                            time_diff=time_diff,
                            config=config,
                            rule_name=rule_name
                        )
                        return  # Stop after the highest severity rule is matched

    def _handle_location_anomaly(self, user, current_location, previous_location, distance, time_diff, config, rule_name):
        """Handle location anomaly based on rule type"""
        if rule_name == 'RAPID_LOCATION_CHANGE':
            self._handle_rapid_location_change(user, current_location, previous_location, distance, time_diff, config)
        elif rule_name == 'IMPOSSIBLE_TRAVEL':
            self._handle_impossible_travel(user, current_location, previous_location, distance, time_diff, config)

    def _handle_rapid_location_change(self, user, current_location, previous_location, distance, time_diff, config):
        """Process detected rapid location change"""
        current_location.is_suspicious = True
        current_location.risk_score += RISK_SCORING_WEIGHTS.get('rapid_location_change', 40)
        current_location.save()
        
        details = {
            'from_location': f"{previous_location.city}, {previous_location.country}",
            'to_location': f"{current_location.city}, {current_location.country}",
            'distance_km': round(distance, 2),
            'time_minutes': round(time_diff, 2),
            'speed_kph': round((distance / time_diff) * 60, 2) if time_diff > 0 else 0,
        }
        
        apply_security_rule(
            user=user,
            rule_name='RAPID_LOCATION_CHANGE',
            activity_type='rapid_location_change',
            location=current_location,
            details=details,
            risk_score=RISK_SCORING_WEIGHTS.get('rapid_location_change', 40),
            reason='Rapid location change detected',
        )
    
    def _detect_impossible_travel(self, user, current_location):
        """Detect impossible travel patterns"""
        config = THREAT_DETECTION_CONFIG.get('IMPOSSIBLE_TRAVEL', {})
        if not config.get('enabled', True):
            return
            
        time_window = config.get('time_window_minutes', 60)
        max_distance = config.get('max_distance_km', 500)
        
        recent_locations = UserLocation.objects.filter(
            user=user,
            last_seen__gte=timezone.now() - timedelta(minutes=time_window)
        ).exclude(pk=current_location.pk).order_by('-last_seen')[:5]
        
        for location in recent_locations:
            if current_location.latitude and current_location.longitude and location.latitude and location.longitude:
                point_a = (location.latitude, location.longitude)
                point_b = (current_location.latitude, current_location.longitude)
                distance = geodesic(point_a, point_b).kilometers
                time_diff = (timezone.now() - location.last_seen).total_seconds() / 60
                
                if time_diff <= time_window and distance > max_distance:
                    self._handle_impossible_travel(
                        user=user,
                        current_location=current_location,
                        previous_location=location,
                        distance=distance,
                        time_diff=time_diff,
                        config=config
                    )
                    break
    
    def _handle_impossible_travel(self, user, current_location, previous_location, distance, time_diff, config):
        """Process detected impossible travel"""
        current_location.is_suspicious = True
        current_location.risk_score += RISK_SCORING_WEIGHTS.get('impossible_travel', 80)
        current_location.save()
        
        apply_security_rule(
            user=user,
            rule_name='IMPOSSIBLE_TRAVEL',
            activity_type='impossible_travel',
            location=current_location,
            details={
                'from_location': f"{previous_location.city}, {previous_location.country}",
                'to_location': f"{current_location.city}, {current_location.country}",
                'distance_km': round(distance, 2),
                'time_minutes': round(time_diff, 2),
                'speed_kph': round((distance / time_diff) * 60, 2) if time_diff > 0 else 0,
            },
            risk_score=RISK_SCORING_WEIGHTS.get('impossible_travel', 80),
            reason='Impossible travel detected',
        )
    
    def _check_device_anomalies(self, user, current_device):
        """Check for suspicious device patterns"""
        self._detect_multiple_device_access(user)
        self._check_device_reputation(current_device)
    
    def _detect_multiple_device_access(self, user):
        """Detect access from multiple devices"""
        config = THREAT_DETECTION_CONFIG.get('MULTIPLE_DEVICE_ACCESS', {})
        if not config.get('enabled', True):
            return
            
        time_window = config.get('time_window_minutes', 60)
        max_devices = config.get('max_devices', 3)
        
        recent_devices_count = DeviceInfo.objects.filter(
            user=user,
            last_used__gte=timezone.now() - timedelta(minutes=time_window)
        ).count()
        
        if recent_devices_count > max_devices:
            apply_security_rule(
                user=user,
                rule_name='MULTIPLE_DEVICE_ACCESS',
                activity_type='multiple_device_access',
                details={
                    'device_count': recent_devices_count,
                    'max_allowed': max_devices,
                    'time_window_minutes': time_window,
                },
                risk_score=RISK_SCORING_WEIGHTS.get('multiple_device_access', 0),
            )
    
    def _check_device_reputation(self, device):
        """Check device reputation (placeholder for future implementation)"""
        pass
    
    def _check_session_anomalies(self, request, user):
        """Check for suspicious session patterns"""
        self._detect_session_hijacking(request, user)
    
    def _detect_session_hijacking(self, request, user):
        """Detect potential session hijacking"""
        session_key = request.session.session_key
        cache_key = f"user_session_{user.id}_{generate_device_fingerprint(request)}"
        expected_session = cache.get(cache_key)
        
        if expected_session and expected_session != session_key:
            log_suspicious_activity(
                user=user,
                activity_type='possible_session_hijack',
                threat_level='HIGH',
                request=request,
                details={
                    'expected_session': expected_session,
                    'actual_session': session_key,
                    'device_fingerprint': generate_device_fingerprint(request),
                }
            )
            
            # Force logout and require reauthentication
            request.session.flush()
    
    def _update_user_risk_profile(self, user):
        """Update user's risk score based on recent activities"""
        try:
            recent_activities = SuspiciousActivityLog.objects.filter(
                user=user,
                timestamp__gte=timezone.now() - timedelta(days=7)
            )
            
            total_risk = 0
            for activity in recent_activities:
                # Use activity type directly
                weight = RISK_SCORING_WEIGHTS.get(activity.activity_type, 0)
                total_risk += weight
                
            # Cap risk score at 100
            total_risk = min(100, total_risk)
            
            # Update user risk profile
            user.risk_score = total_risk
            user.save(update_fields=['risk_score'])
            
        except Exception as e:
            logger.error(f"Failed to update risk profile for user {user.id}: {str(e)}")

# File Access Tracking Decorator
def track_file_access(view_func):
    """Decorator to track and analyze file access patterns"""
    def wrapper(request, *args, **kwargs):
        if request.user.is_authenticated:
            # Track access pattern
            analyze_file_access_pattern(request)
            
            # Check bulk access
            if is_bulk_file_access(request.user):
                handle_bulk_access(request)
            
            # Check unusual time access
            if not is_access_time_allowed(request):
                handle_unusual_time_access(request)
        
        return view_func(request, *args, **kwargs)
    
    return wrapper

def analyze_file_access_pattern(request):
    """Analyze file access patterns for anomalies (placeholder)"""
    # Implementation would track specific file access patterns
    pass

def is_bulk_file_access(user):
    """Check for bulk file access patterns"""
    config = THREAT_DETECTION_CONFIG.get('BULK_FILE_ACCESS', {})
    cache_key = f"file_access_{user.id}"
    count = cache.get(cache_key, 0) + 1
    cache.set(cache_key, count, config.get('time_window_minutes', 5) * 60)
    return count > config.get('max_files', 10)

def handle_bulk_access(request):
    """Process bulk file access detection"""
    config = THREAT_DETECTION_CONFIG.get('BULK_FILE_ACCESS', {})
    
    apply_security_rule(
        user=request.user,
        rule_name='BULK_FILE_ACCESS',
        activity_type='bulk_file_access',
        ip_address=get_client_ip(request),
        details={
            'files_accessed': cache.get(f"file_access_{request.user.id}", 0),
            'time_window': config.get('time_window_minutes', 5),
        },
        risk_score=RISK_SCORING_WEIGHTS.get('bulk_file_access', 30),
    )

def handle_unusual_time_access(request):
    """Handle unusual time access for file access"""
    config = THREAT_DETECTION_CONFIG.get('UNUSUAL_FILE_ACCESS', {})
    
    # Log the user's local time, not UTC
    user_tz_name = _resolve_user_timezone(request.user)
    try:
        tz = pytz.timezone(user_tz_name)
    except pytz.UnknownTimeZoneError:
        tz = pytz.timezone(settings.TIME_ZONE)
    user_now = timezone.now().astimezone(tz)
    
    apply_security_rule(
        user=request.user,
        rule_name='UNUSUAL_FILE_ACCESS',
        activity_type='unusual_file_access',
        ip_address=get_client_ip(request),
        details={
            'access_time': str(user_now),
            'timezone': user_tz_name,
        },
        risk_score=RISK_SCORING_WEIGHTS.get('unusual_time', 25),
        reason='Unusual file access time detected',
    )
