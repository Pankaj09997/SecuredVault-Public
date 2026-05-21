from django.db import models
from django.contrib.auth.models import BaseUserManager, AbstractBaseUser
from django.utils import timezone
from django.conf import settings
from django.core.validators import FileExtensionValidator
import uuid
import os
import json
import secrets
import string
from datetime import timedelta
from geopy.distance import geodesic
from django.utils import timezone
from datetime import timedelta



class MyUserManager(BaseUserManager):
    def create_user(self, email, name, password=None, image=None,
                    otp_code=None, otp_created_at=None, is_verified=False):
        if not email:
            raise ValueError("Users must have an email address")
        email = self.normalize_email(email).lower()
        user = self.model(
            email=email,
            name=name,
            image=image,
            otp_code=otp_code,
            otp_created_at=otp_created_at,
            is_verified=is_verified,
        )
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, name, password=None):
        user = self.create_user(email=email, name=name, password=password)
        user.is_admin = True
        user.is_verified = True
        user.save(using=self._db)
        return user


class MyUser(AbstractBaseUser):
    email = models.EmailField(verbose_name="email address", max_length=255, unique=True)
    name = models.CharField(max_length=255)
    image = models.ImageField(
        upload_to='profile_pictures/', blank=True, null=True,
        validators=[FileExtensionValidator(allowed_extensions=['jpg', 'jpeg', 'png'])],
    )
    risk_score = models.IntegerField(default=0)

    is_active = models.BooleanField(default=True)
    is_admin = models.BooleanField(default=False)
    is_verified = models.BooleanField(default=False)

    # OTP
    otp_code = models.CharField(max_length=6, blank=True, null=True)
    otp_created_at = models.DateTimeField(blank=True, null=True)
    reset_otp_code = models.CharField(max_length=6, blank=True, null=True)

    # Security tracking
    last_login_location = models.JSONField(blank=True, null=True)
    last_login_time = models.DateTimeField(null=True, blank=True)
    current_device = models.ForeignKey(
        'DeviceInfo', on_delete=models.SET_NULL, null=True, blank=True,
    )

    # Account lockout
    failed_login_attempts = models.PositiveIntegerField(default=0)
    account_locked_until = models.DateTimeField(null=True, blank=True)
    is_temporarily_blocked = models.BooleanField(default=False)
    blocked_until = models.DateTimeField(null=True, blank=True)
    blocked_reason = models.CharField(max_length=255, blank=True, null=True)

    # Password change tracking — tokens issued before this timestamp are rejected
    password_changed_at = models.DateTimeField(null=True, blank=True)

    # Notification prefs
    email_notifications_enabled = models.BooleanField(default=True)
    security_alerts_enabled = models.BooleanField(default=True)

    # E2EE public keys (private keys NEVER leave the device)
    # RSA public key — used by senders to wrap AES keys for this user
    rsa_public_key = models.TextField(blank=True, null=True)        # PEM format
    # Ed25519 public key — used by receivers to verify this user's signatures
    ed25519_public_key = models.TextField(blank=True, null=True)    # PEM format

    objects = MyUserManager()
    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["name"]

    def __str__(self):
        return self.email

    def has_perm(self, perm, obj=None):
        return True

    def has_module_perms(self, app_label):
        return True

    @property
    def is_staff(self):
        return self.is_admin

    def is_account_locked(self):
        return bool(self.account_locked_until and timezone.now() < self.account_locked_until)

    def is_temporarily_blocked_active(self):
        return bool(self.blocked_until and timezone.now() < self.blocked_until)


# ---------------------------------------------------------------------------
# Location & device tracking
# ---------------------------------------------------------------------------

class UserLocation(models.Model):
    user = models.ForeignKey(MyUser, on_delete=models.CASCADE, related_name='locations')
    ip_address = models.GenericIPAddressField()
    country = models.CharField(max_length=100)
    region = models.CharField(max_length=100)
    city = models.CharField(max_length=100)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    isp = models.CharField(max_length=100, null=True, blank=True)
    timezone = models.CharField(max_length=50, null=True, blank=True)
    first_seen = models.DateTimeField(auto_now_add=True)
    last_seen = models.DateTimeField(auto_now=True)
    is_trusted = models.BooleanField(default=False)
    access_count = models.PositiveIntegerField(default=1)
    is_suspicious = models.BooleanField(default=False)
    risk_score = models.IntegerField(default=0)

    class Meta:
        unique_together = ('user', 'ip_address')
        ordering = ['-last_seen']

    def __str__(self):
        return f"{self.user.email} - {self.city}, {self.country} ({self.ip_address})"

    def distance_from(self, other_location):
        """Return distance in km between this location and another, or None."""
        if not all([self.latitude, self.longitude,
                    other_location and other_location.latitude,
                    other_location and other_location.longitude]):
            return None
        return geodesic(
            (self.latitude, self.longitude),
            (other_location.latitude, other_location.longitude),
        ).kilometers


class DeviceInfo(models.Model):
    user = models.ForeignKey(MyUser, on_delete=models.CASCADE, related_name='devices')
    device_id = models.CharField(max_length=255)
    device_name = models.CharField(max_length=100, blank=True, null=True)
    model = models.CharField(max_length=100, blank=True, null=True)
    manufacturer = models.CharField(max_length=100, blank=True, null=True)
    os = models.CharField(max_length=50, blank=True, null=True)
    os_version = models.CharField(max_length=50, blank=True, null=True)
    is_physical_device = models.BooleanField(default=True)
    app_version = models.CharField(max_length=50, blank=True, null=True)
    first_seen = models.DateTimeField(auto_now_add=True)
    last_used = models.DateTimeField(auto_now=True)
    is_trusted = models.BooleanField(default=False)
    is_verified = models.BooleanField(default=False)
    browser_info = models.TextField(blank=True, null=True)
    user_agent = models.TextField(blank=True, null=True)
    login_count = models.PositiveIntegerField(default=0)
    last_login_location = models.ForeignKey(
        UserLocation, on_delete=models.SET_NULL, null=True, blank=True,
    )

    class Meta:
        unique_together = ('user', 'device_id')
        ordering = ['-last_used']

    def __str__(self):
        return f"{self.user.email}'s {self.device_name or 'device'}"


class DeviceVerification(models.Model):
    user = models.ForeignKey(MyUser, on_delete=models.CASCADE, related_name='device_verifications')
    device = models.ForeignKey(DeviceInfo, on_delete=models.CASCADE, related_name='verifications')
    token = models.UUIDField(default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_verified = models.BooleanField(default=False)

    def save(self, *args, **kwargs):
        if not self.pk and not self.expires_at:
            self.expires_at = timezone.now() + timedelta(hours=24)
        super().save(*args, **kwargs)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'created_at']),
            models.Index(fields=['token']),
        ]

    def __str__(self):
        return f"Verification for {self.user.email} — device {self.device.device_id}"


# ---------------------------------------------------------------------------
# Threat detection
# ---------------------------------------------------------------------------

THREAT_LEVEL_CHOICES = [
    ('LOW', 'Low risk'),
    ('MEDIUM', 'Medium risk'),
    ('HIGH', 'High risk'),
    ('CRITICAL', 'Critical risk'),
]


class ThreatDetectionRule(models.Model):
    rule_name = models.CharField(max_length=100, unique=True)
    threat_level = models.CharField(max_length=10, choices=THREAT_LEVEL_CHOICES)
    description = models.TextField()
    is_active = models.BooleanField(default=True)
    max_distance_km = models.IntegerField(null=True, blank=True)
    time_window_minutes = models.IntegerField(null=True, blank=True)
    max_failed_attempts = models.IntegerField(null=True, blank=True)
    should_block = models.BooleanField(default=False)
    should_notify = models.BooleanField(default=True)
    should_log = models.BooleanField(default=True)
    block_duration_minutes = models.IntegerField(default=60)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.rule_name} ({self.threat_level})"


class SuspiciousActivityLog(models.Model):
    ACTIVITY_CHOICES = [
        ('login', 'Login attempt'),
        ('new_device', 'New device login'),
        ('new_location', 'New location'),
        ('location_change', 'Location change'),
        ('file_access', 'File access'),
        ('image_access', 'Image access'),
        ('password_change', 'Password change'),
        ('unusual_time_access', 'Unusual time access'),
        ('unusual_time', 'Unusual time access'),
        ('rapid_location_change', 'Rapid location change'),
        ('impossible_travel', 'Impossible travel'),
        ('multiple_device_access', 'Multiple device access'),
        ('multiple_failed_login', 'Multiple failed logins'),
        ('possible_session_hijack', 'Possible session hijack'),
        ('bulk_file_access', 'Bulk file access'),
        ('unusual_file_access', 'Unusual file access'),
        ('tampering_detected', 'Data tampering detected'),  # NEW — GCM auth failure
    ]

    ACTION_CHOICES = [
        ('logged', 'Logged'),
        ('blocked', 'Blocked'),
        ('notified', 'Notified'),
        ('verified', 'Verified'),
        ('ignored', 'Ignored'),
    ]

    user = models.ForeignKey(MyUser, on_delete=models.CASCADE, related_name='suspicious_activities')
    activity_type = models.CharField(max_length=30, choices=ACTIVITY_CHOICES)
    threat_level = models.CharField(max_length=10, choices=THREAT_LEVEL_CHOICES)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    location = models.ForeignKey(UserLocation, on_delete=models.SET_NULL, null=True, blank=True)
    device = models.ForeignKey(DeviceInfo, on_delete=models.SET_NULL, null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)
    details = models.JSONField(default=dict)
    risk_score = models.IntegerField(default=0)
    action_taken = models.CharField(max_length=20, choices=ACTION_CHOICES, default='logged')
    email_sent = models.BooleanField(default=False)
    user_blocked = models.BooleanField(default=False)
    is_resolved = models.BooleanField(default=False)
    resolved_at = models.DateTimeField(null=True, blank=True)
    resolved_by = models.ForeignKey(
        MyUser, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='resolved_activities',
    )

    class Meta:
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['user', 'timestamp']),
            models.Index(fields=['threat_level', 'timestamp']),
            models.Index(fields=['activity_type', 'timestamp']),
        ]

    def __str__(self):
        return f"{self.get_threat_level_display()} — {self.get_activity_type_display()} for {self.user.email}"


class LoginAttempt(models.Model):
    STATUS_CHOICES = [
        ('success', 'Success'),
        ('failed', 'Failed'),
        ('blocked', 'Blocked'),
    ]

    user = models.ForeignKey(
        MyUser, on_delete=models.CASCADE, related_name='login_attempts',
        null=True, blank=True,
    )
    email_attempted = models.EmailField()
    ip_address = models.GenericIPAddressField()
    location = models.ForeignKey(UserLocation, on_delete=models.SET_NULL, null=True, blank=True)
    device = models.ForeignKey(DeviceInfo, on_delete=models.SET_NULL, null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES)
    user_agent = models.TextField(blank=True, null=True)
    failure_reason = models.CharField(max_length=255, blank=True, null=True)
    is_suspicious = models.BooleanField(default=False)

    class Meta:
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['user', 'timestamp']),
            models.Index(fields=['ip_address', 'timestamp']),
            models.Index(fields=['status', 'timestamp']),
        ]

    def __str__(self):
        return f"{self.email_attempted} — {self.status} at {self.timestamp}"


# ---------------------------------------------------------------------------
# Encrypted file storage
# AES-256-GCM: each encrypted object stores its own nonce (12 bytes) and
# authentication tag (16 bytes) separately from the IV used to wrap the key.
# The master-key wrap also uses GCM with its own independent nonce so the
# same nonce is NEVER reused across the two encryption operations.
# Decryption logic lives exclusively in securevault/crypto.py (utils layer).
# ---------------------------------------------------------------------------

class EncryptedFile(models.Model):
    user = models.ForeignKey(MyUser, on_delete=models.CASCADE, related_name='files')
    original_name = models.CharField(max_length=255)
    encrypted_name = models.CharField(max_length=255, unique=True)
    file_type = models.CharField(max_length=50)
    file_size = models.PositiveIntegerField()

    # --- key-wrapping fields (master key encrypts the per-file AES key) ---
    encrypted_aes_key = models.BinaryField()          # ciphertext of the AES key
    key_wrap_nonce = models.BinaryField()              # 12-byte GCM nonce for key-wrap
    key_wrap_tag = models.BinaryField()                # 16-byte GCM auth tag for key-wrap

    # --- file-content encryption fields ---
    file_nonce = models.BinaryField()                  # 12-byte GCM nonce for file content
    file_tag = models.BinaryField()                    # 16-byte GCM auth tag for file content

    upload_date = models.DateTimeField(auto_now_add=True)
    access_count = models.PositiveIntegerField(default=0)
    last_accessed = models.DateTimeField(null=True, blank=True)

    def get_file_path(self):
        return os.path.join(settings.MEDIA_ROOT, 'encrypted', self.encrypted_name)

    def __str__(self):
        return f"{self.user.email} — {self.original_name}"


class EncryptedImage(models.Model):
    user = models.ForeignKey(MyUser, on_delete=models.CASCADE, related_name='images')
    original_name = models.CharField(max_length=255)
    encrypted_name = models.CharField(max_length=255, unique=True)
    image_type = models.CharField(max_length=50)
    image_size = models.PositiveIntegerField()

    # --- key-wrapping fields ---
    encrypted_aes_key = models.BinaryField()
    key_wrap_nonce = models.BinaryField()
    key_wrap_tag = models.BinaryField()

    # --- image-content encryption fields ---
    file_nonce = models.BinaryField()
    file_tag = models.BinaryField()

    upload_date = models.DateTimeField(auto_now_add=True)
    access_count = models.PositiveIntegerField(default=0)
    last_accessed = models.DateTimeField(null=True, blank=True)

    def get_image_path(self):
        return os.path.join(settings.MEDIA_ROOT, 'EncryptedImage', self.encrypted_name)

    def __str__(self):
        return f"{self.user.email} — {self.original_name}"


# ---------------------------------------------------------------------------
# Access logs
# ---------------------------------------------------------------------------

class FileAccessLog(models.Model):
    file = models.ForeignKey(EncryptedFile, on_delete=models.CASCADE, related_name='access_logs')
    user = models.ForeignKey(MyUser, on_delete=models.CASCADE)
    device = models.ForeignKey(DeviceInfo, on_delete=models.SET_NULL, null=True, blank=True)
    location = models.ForeignKey(UserLocation, on_delete=models.SET_NULL, null=True, blank=True)
    access_time = models.DateTimeField(auto_now_add=True)
    action = models.CharField(max_length=20)
    ip_address = models.GenericIPAddressField()
    country = models.CharField(max_length=100, null=True, blank=True)
    region = models.CharField(max_length=100, null=True, blank=True)
    city = models.CharField(max_length=100, null=True, blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    isp = models.CharField(max_length=100, null=True, blank=True)
    timezone = models.CharField(max_length=50, null=True, blank=True)
    is_suspicious = models.BooleanField(default=False)
    threat_level = models.CharField(
        max_length=10, choices=THREAT_LEVEL_CHOICES, null=True, blank=True,
    )

    class Meta:
        ordering = ['-access_time']
        indexes = [
            models.Index(fields=['user', 'access_time']),
            models.Index(fields=['file', 'access_time']),
            models.Index(fields=['is_suspicious', 'access_time']),
        ]

    def __str__(self):
        return f"{self.user.email} {self.action} {self.file.original_name}"


class ImageAccessLog(models.Model):
    image = models.ForeignKey(EncryptedImage, on_delete=models.CASCADE, related_name='access_logs')
    user = models.ForeignKey(MyUser, on_delete=models.CASCADE)
    device = models.ForeignKey(DeviceInfo, on_delete=models.SET_NULL, null=True, blank=True)
    location = models.ForeignKey(UserLocation, on_delete=models.SET_NULL, null=True, blank=True)
    access_time = models.DateTimeField(auto_now_add=True)
    action = models.CharField(max_length=50)
    ip_address = models.GenericIPAddressField()
    country = models.CharField(max_length=100, null=True, blank=True)
    region = models.CharField(max_length=100, null=True, blank=True)
    city = models.CharField(max_length=100, null=True, blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    isp = models.CharField(max_length=100, null=True, blank=True)
    timezone = models.CharField(max_length=50, null=True, blank=True)
    is_suspicious = models.BooleanField(default=False)
    threat_level = models.CharField(
        max_length=10, choices=THREAT_LEVEL_CHOICES, null=True, blank=True,
    )

    class Meta:
        ordering = ['-access_time']
        indexes = [
            models.Index(fields=['user', 'access_time']),
            models.Index(fields=['image', 'access_time']),
            models.Index(fields=['is_suspicious', 'access_time']),
        ]

    def __str__(self):
        return f"{self.user.email} {self.action} {self.image.original_name}"


# ---------------------------------------------------------------------------
# Shared resources
# ---------------------------------------------------------------------------

class SharedFileResource(models.Model):
    RESOURCE_TYPES = (
        ('file', 'File'),
        ('image', 'Image'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    resource_type = models.CharField(max_length=10, choices=RESOURCE_TYPES)
    file = models.ForeignKey(EncryptedFile, on_delete=models.CASCADE, null=True, blank=True)
    image = models.ForeignKey(EncryptedImage, on_delete=models.CASCADE, null=True, blank=True)
    creator = models.ForeignKey(MyUser, on_delete=models.CASCADE)

    # Recipient binding — prevents link hijacking
    recipient = models.ForeignKey(
        MyUser, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='received_shares',
    )
    recipient_key_fingerprint = models.CharField(max_length=64, blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    viewer_ip = models.GenericIPAddressField(null=True, blank=True)
    

    # Digital signature fields (see previous discussion on impersonation prevention)
    sender_signature = models.BinaryField(null=True, blank=True)   # Ed25519 signature
    payload_hash = models.CharField(max_length=64, blank=True, null=True)  # SHA-256 of file

    # def save(self, *args, **kwargs):
    #     if not self.pk and not self.expires_at:
    #         self.expires_at = timezone.now() + timedelta(minutes=10)
    #     super().save(*args, **kwargs)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['creator', 'created_at']),
            models.Index(fields=['expires_at']),
        ]

    def __str__(self):
        return f"Share {self.id} by {self.creator.email}"


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

class SecurityNotification(models.Model):
    NOTIFICATION_TYPES = [
        ('new_device', 'New device login'),
        ('suspicious_activity', 'Suspicious activity'),
        ('account_locked', 'Account locked'),
        ('location_change', 'Location change'),
        ('unusual_access', 'Unusual access time'),
        ('tampering_detected', 'Data tampering detected'),  # NEW
    ]

    user = models.ForeignKey(MyUser, on_delete=models.CASCADE, related_name='security_notifications')
    notification_type = models.CharField(max_length=30, choices=NOTIFICATION_TYPES)
    title = models.CharField(max_length=255)
    message = models.TextField()
    suspicious_activity = models.ForeignKey(
        SuspiciousActivityLog, on_delete=models.CASCADE, null=True, blank=True,
    )
    device = models.ForeignKey(DeviceInfo, on_delete=models.SET_NULL, null=True, blank=True)
    location = models.ForeignKey(UserLocation, on_delete=models.SET_NULL, null=True, blank=True)
    sent_at = models.DateTimeField(auto_now_add=True)
    email_sent = models.BooleanField(default=False)
    email_sent_at = models.DateTimeField(null=True, blank=True)
    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-sent_at']

    def __str__(self):
        return f"{self.get_notification_type_display()} for {self.user.email}"


# ---------------------------------------------------------------------------
# P2P rooms and file transfer
# ---------------------------------------------------------------------------

class Room(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(MyUser, on_delete=models.CASCADE, related_name='owned_rooms')
    name = models.CharField(max_length=100)
    passcode = models.CharField(max_length=8, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)
    max_peers = models.IntegerField(default=10)

    def save(self, *args, **kwargs):
        if not self.passcode:
            self.passcode = ''.join(secrets.choice(string.digits) for _ in range(6))
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.name} ({self.passcode})"


class Peer(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(MyUser, on_delete=models.CASCADE, related_name='peers')
    room = models.ForeignKey(Room, on_delete=models.CASCADE, related_name='peers')
    peer_id = models.CharField(max_length=100)
    device_name = models.CharField(max_length=100, default='Unknown device')
    is_authenticated = models.BooleanField(default=False)
    is_connected = models.BooleanField(default=True)
    joined_at = models.DateTimeField(auto_now_add=True)
    last_seen = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('room', 'peer_id')

    def __str__(self):
        return f"{self.peer_id} ({self.device_name}) in {self.room.name}"


class FileTransfer(models.Model):
    TRANSFER_STATUS = (
        ('pending', 'Pending'),
        ('in_progress', 'In progress'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    sender = models.ForeignKey(MyUser, related_name='sent_transfers', on_delete=models.CASCADE)
    receiver = models.ForeignKey(MyUser, related_name='received_transfers', on_delete=models.CASCADE)
    room = models.ForeignKey(Room, on_delete=models.CASCADE)
    file = models.ForeignKey(EncryptedFile, on_delete=models.SET_NULL, null=True, blank=True)

    file_name = models.CharField(max_length=255)
    file_size = models.BigIntegerField()
    file_type = models.CharField(max_length=100)
    status = models.CharField(max_length=20, choices=TRANSFER_STATUS, default='pending')

    # Per-transfer AES-GCM fields (key encrypted with receiver's RSA public key)
    encrypted_aes_key = models.BinaryField(null=True, blank=True)
    file_nonce = models.BinaryField(null=True, blank=True)       # 12-byte GCM nonce
    file_tag = models.BinaryField(null=True, blank=True)         # 16-byte GCM auth tag

    # RSA key exchange
    sender_public_key = models.TextField()                        # PEM — sender's public key
    receiver_public_key = models.TextField(null=True, blank=True) # PEM — receiver's public key

    # Digital signature (impersonation prevention)
    sender_signature = models.BinaryField(null=True, blank=True)  # Ed25519 sig of file hash
    payload_hash = models.CharField(max_length=64, blank=True, null=True)

    # Transfer progress
    chunk_count = models.IntegerField()
    chunks_received = models.IntegerField(default=0)
    last_chunk_index = models.IntegerField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    transfer_speed = models.FloatField(null=True, blank=True)  # MB/s

    class Meta:
        ordering = ['-created_at']

    def progress(self):
        if self.chunk_count > 0:
            return round((self.chunks_received / self.chunk_count) * 100, 1)
        return 0.0

    def __str__(self):
        return f"Transfer {self.id}: {self.file_name} ({self.status})"
