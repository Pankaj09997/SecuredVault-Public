# security_config.py
from django.conf import settings

# Threat Detection Configuration
# generally this works in middleware,system signals 
THREAT_DETECTION_CONFIG = {
    'UNUSUAL_ACCESS_HOURS': {
        'start_hour': 23,
        'end_hour': 5,
        'threat_level': 'HIGH',
        'overnight': True,
        'should_block': True,
        'block_duration_minutes': 60,
    },
    'RAPID_LOCATION_CHANGE': {
        'max_distance_km': 100,
        'time_window_minutes': 30,
        'threat_level': 'MEDIUM',
        'should_block': False,
        'should_notify': True,
    },
    'IMPOSSIBLE_TRAVEL': {
        'max_distance_km': 500,
        'time_window_minutes': 60,
        'threat_level': 'HIGH',
        'should_block': True,
        'should_notify': True,
        'block_duration_minutes': 120,
    },
    'NEW_DEVICE_LOGIN': {
        'threat_level': 'LOW',
        'should_block': False,
        'should_notify': True,
        'require_verification': True,
    },
    'MULTIPLE_DEVICE_ACCESS': {
        'max_devices': 3,
        'time_window_minutes': 60,
        'threat_level': 'MEDIUM',
        'should_block': False,
        'should_notify': True,
    },
    'FAILED_LOGIN_ATTEMPTS': {
        'max_attempts': 5,
        'time_window_minutes': 15,
        'threat_level': 'HIGH',
        'should_block': True,
        'block_duration_minutes': 30,
    },
    'BULK_FILE_ACCESS': {
        'max_files': 10,
        'time_window_minutes': 5,
        'threat_level': 'MEDIUM',
        'should_notify': True,
    },
    'UNUSUAL_FILE_ACCESS': {
        'unusual_hours': True,
        'threat_level': 'HIGH',
        'should_block': True,
        'block_duration_minutes': 60,
    },
}

# Risk scoring weights
RISK_SCORING_WEIGHTS = {
    'new_device': 10,
    'new_location': 15,
    'unusual_time': 25,
    'rapid_location_change': 40,
    'impossible_travel': 80,
    'multiple_failed_logins': 50,
    'bulk_file_access': 30,
    'untrusted_device': 20,
    'untrusted_location': 15,
}

# Notification settings
NOTIFICATION_SETTINGS = {
    'email_cooldown_minutes': 15,  # Don't spam emails and send it after every 15 minutes
    'max_notifications_per_hour': 5,
    'critical_threat_immediate_notify': True,
}

# Default threat detection rules to create
# they are usually stored in the database
DEFAULT_THREAT_RULES = [
    {
        'rule_name': 'new_device_login',
        'threat_level': 'LOW',
        'description': 'User logged in from a new device',
        'should_block': False,
        'should_notify': True,
    },
    {
        'rule_name': 'unusual_time_access',
        'threat_level': 'HIGH',
        'description': 'File access during unusual hours (11PM - 5AM)',
        'should_block': True,
        'should_notify': True,
        'block_duration_minutes': 60,
    },
    {
        'rule_name': 'rapid_location_change',
        'threat_level': 'MEDIUM',
        'description': 'User location changed rapidly (Kathmandu to Dhangadhi)',
        'max_distance_km': 100,
        'time_window_minutes': 30,
        'should_block': False,
        'should_notify': True,
    },
    {
        'rule_name': 'impossible_travel',
        'threat_level': 'HIGH',
        'description': 'Impossible travel detected between locations',
        'max_distance_km': 500,
        'time_window_minutes': 60,
        'should_block': True,
        'should_notify': True,
        'block_duration_minutes': 120,
    },
    {
        'rule_name': 'multiple_failed_logins',
        'threat_level': 'HIGH',
        'description': 'Multiple failed login attempts detected',
        'max_failed_attempts': 5,
        'time_window_minutes': 15,
        'should_block': True,
        'should_notify': True,
        'block_duration_minutes': 30,
    },
]