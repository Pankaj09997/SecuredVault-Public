from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.forms import ReadOnlyPasswordHashField
from django.core.exceptions import ValidationError
from django.utils import timezone
from django import forms

from api.models import (
    MyUser, UserLocation, DeviceInfo, DeviceVerification,
    ThreatDetectionRule, SuspiciousActivityLog, LoginAttempt,
    EncryptedFile, EncryptedImage, FileAccessLog, ImageAccessLog,
    SharedFileResource, SecurityNotification, Room, Peer, FileTransfer,
)


# ---------------------------------------------------------------------------
# User forms
# ---------------------------------------------------------------------------

class UserCreationForm(forms.ModelForm):
    password1 = forms.CharField(label="Password", widget=forms.PasswordInput)
    password2 = forms.CharField(label="Password confirmation", widget=forms.PasswordInput)

    class Meta:
        model = MyUser
        fields = ["email", "name"]

    def clean_password2(self):
        p1 = self.cleaned_data.get("password1")
        p2 = self.cleaned_data.get("password2")
        if p1 and p2 and p1 != p2:
            raise ValidationError("Passwords don't match")
        return p2

    def save(self, commit=True):
        user = super().save(commit=False)
        user.set_password(self.cleaned_data["password1"])
        if commit:
            user.save()
        return user


class UserChangeForm(forms.ModelForm):
    password = ReadOnlyPasswordHashField()

    class Meta:
        model = MyUser
        fields = ["email", "password", "name", "is_active", "is_admin"]


# ---------------------------------------------------------------------------
# MyUser admin
# ---------------------------------------------------------------------------

@admin.register(MyUser)
class UserAdmin(BaseUserAdmin):
    form = UserChangeForm
    add_form = UserCreationForm

    list_display = [
        "email", "name", "is_verified", "is_admin", "is_active",
        "risk_score", "failed_login_attempts", "is_temporarily_blocked",
        "last_login_time",
    ]
    list_filter = ["is_admin", "is_active", "is_verified", "is_temporarily_blocked"]
    search_fields = ["email", "name"]
    ordering = ["email"]
    filter_horizontal = []
    readonly_fields = ["last_login_time", "risk_score"]

    fieldsets = [
        ("Credentials", {"fields": ["email", "password"]}),
        ("Personal info", {"fields": ["name", "image"]}),
        ("Permissions", {"fields": ["is_admin", "is_active", "is_verified"]}),
        ("Security", {
            "fields": [
                "risk_score", "failed_login_attempts",
                "account_locked_until", "is_temporarily_blocked",
                "blocked_until", "blocked_reason",
            ],
        }),
        ("Notifications", {
            "fields": ["email_notifications_enabled", "security_alerts_enabled"],
        }),
        ("Tracking", {
            "fields": ["last_login_time", "last_login_location", "current_device"],
            "classes": ["collapse"],
        }),
    ]

    add_fieldsets = [
        (None, {
            "classes": ["wide"],
            "fields": ["email", "name", "password1", "password2"],
        }),
    ]

    actions = ["unlock_accounts", "reset_risk_scores"]

    @admin.action(description="Unlock selected accounts")
    def unlock_accounts(self, request, queryset):
        queryset.update(
            account_locked_until=None,
            failed_login_attempts=0,
            is_temporarily_blocked=False,
            blocked_until=None,
            blocked_reason=None,
        )
        self.message_user(request, f"{queryset.count()} account(s) unlocked.")

    @admin.action(description="Reset risk scores to 0")
    def reset_risk_scores(self, request, queryset):
        queryset.update(risk_score=0)
        self.message_user(request, f"{queryset.count()} risk score(s) reset.")


# ---------------------------------------------------------------------------
# Location & device
# ---------------------------------------------------------------------------

@admin.register(UserLocation)
class UserLocationAdmin(admin.ModelAdmin):
    list_display = [
        "user", "city", "country", "ip_address", "isp",
        "is_trusted", "is_suspicious", "risk_score",
        "access_count", "first_seen", "last_seen",
    ]
    list_filter = ["is_trusted", "is_suspicious", "country"]
    search_fields = ["user__email", "ip_address", "city", "country", "isp"]
    ordering = ["-last_seen"]
    readonly_fields = ["first_seen", "last_seen", "access_count"]

    actions = ["mark_trusted", "mark_suspicious"]

    @admin.action(description="Mark selected locations as trusted")
    def mark_trusted(self, request, queryset):
        queryset.update(is_trusted=True, is_suspicious=False)

    @admin.action(description="Mark selected locations as suspicious")
    def mark_suspicious(self, request, queryset):
        queryset.update(is_suspicious=True, is_trusted=False)


@admin.register(DeviceInfo)
class DeviceInfoAdmin(admin.ModelAdmin):
    list_display = [
        "user", "device_name", "model", "os", "os_version",
        "is_trusted", "is_verified", "is_physical_device",
        "login_count", "first_seen", "last_used",
    ]
    list_filter = ["is_trusted", "is_verified", "is_physical_device", "os"]
    search_fields = ["user__email", "device_id", "device_name", "model", "manufacturer"]
    ordering = ["-last_used"]
    readonly_fields = ["first_seen", "last_used", "login_count"]

    actions = ["trust_devices", "revoke_trust"]

    @admin.action(description="Mark selected devices as trusted")
    def trust_devices(self, request, queryset):
        queryset.update(is_trusted=True)

    @admin.action(description="Revoke trust from selected devices")
    def revoke_trust(self, request, queryset):
        queryset.update(is_trusted=False, is_verified=False)


@admin.register(DeviceVerification)
class DeviceVerificationAdmin(admin.ModelAdmin):
    list_display = ["user", "device", "is_verified", "created_at", "expires_at"]
    list_filter = ["is_verified"]
    search_fields = ["user__email", "device__device_name"]
    ordering = ["-created_at"]
    readonly_fields = ["token", "created_at"]


# ---------------------------------------------------------------------------
# Threat detection
# ---------------------------------------------------------------------------

@admin.register(ThreatDetectionRule)
class ThreatDetectionRuleAdmin(admin.ModelAdmin):
    list_display = [
        "rule_name", "threat_level", "is_active",
        "should_block", "should_notify", "should_log",
        "block_duration_minutes", "updated_at",
    ]
    list_filter = ["threat_level", "is_active", "should_block"]
    search_fields = ["rule_name", "description"]
    ordering = ["threat_level", "rule_name"]
    readonly_fields = ["created_at", "updated_at"]

    fieldsets = [
        ("Rule identity", {"fields": ["rule_name", "threat_level", "description", "is_active"]}),
        ("Thresholds", {
            "fields": ["max_distance_km", "time_window_minutes", "max_failed_attempts"],
        }),
        ("Response actions", {
            "fields": ["should_block", "should_notify", "should_log", "block_duration_minutes"],
        }),
        ("Timestamps", {"fields": ["created_at", "updated_at"], "classes": ["collapse"]}),
    ]


@admin.register(SuspiciousActivityLog)
class SuspiciousActivityLogAdmin(admin.ModelAdmin):
    list_display = [
        "user", "activity_type", "threat_level", "risk_score",
        "ip_address", "action_taken", "email_sent", "user_blocked",
        "is_resolved", "timestamp",
    ]
    list_filter = [
        "threat_level", "activity_type", "action_taken",
        "is_resolved", "email_sent", "user_blocked",
    ]
    search_fields = ["user__email", "ip_address", "details"]
    ordering = ["-timestamp"]
    readonly_fields = ["timestamp"]
    date_hierarchy = "timestamp"

    actions = ["mark_resolved", "mark_ignored"]

    @admin.action(description="Mark selected activities as resolved")
    def mark_resolved(self, request, queryset):
        queryset.update(
            is_resolved=True,
            resolved_at=timezone.now(),
            resolved_by=request.user,
        )
        self.message_user(request, f"{queryset.count()} activity/activities resolved.")

    @admin.action(description="Mark selected activities as ignored")
    def mark_ignored(self, request, queryset):
        queryset.update(action_taken="ignored")


@admin.register(LoginAttempt)
class LoginAttemptAdmin(admin.ModelAdmin):
    list_display = [
        "email_attempted", "user", "status", "ip_address",
        "is_suspicious", "failure_reason", "timestamp",
    ]
    list_filter = ["status", "is_suspicious"]
    search_fields = ["email_attempted", "ip_address", "user__email"]
    ordering = ["-timestamp"]
    readonly_fields = ["timestamp"]
    date_hierarchy = "timestamp"


# ---------------------------------------------------------------------------
# Encrypted file storage
# ---------------------------------------------------------------------------
admin.site.register(EncryptedFile)
# @admin.register(EncryptedFile)
# class EncryptedFileAdmin(admin.ModelAdmin):
#     list_display = [
#         "user", "original_name", "file_type", "file_size_display",
#         "access_count", "upload_date", "last_accessed",
#     ]
#     list_filter = ["file_type"]
#     search_fields = ["user__email", "original_name", "encrypted_name"]
#     ordering = ["-upload_date"]
#     readonly_fields = [
#         "encrypted_name", "upload_date", "access_count", "last_accessed",
#         "encrypted_aes_key", "key_wrap_nonce", "key_wrap_tag",
#         "file_nonce", "file_tag",
#     ]
#     date_hierarchy = "upload_date"

#     fieldsets = [
#         ("File info", {"fields": ["user", "original_name", "encrypted_name", "file_type", "file_size"]}),
#         ("Usage", {"fields": ["access_count", "last_accessed", "upload_date"]}),
#         ("Crypto fields (read-only)", {
#             "fields": ["encrypted_aes_key", "key_wrap_nonce", "key_wrap_tag", "file_nonce", "file_tag"],
#             "classes": ["collapse"],
#             "description": "These fields are stored for decryption only and cannot be edited here.",
#         }),
#     ]

#     def file_size_display(self, obj):
#         size = obj.file_size
#         if size < 1024:
#             return f"{size} B"
#         elif size < 1024 ** 2:
#             return f"{size / 1024:.1f} KB"
#         else:
#             return f"{size / 1024 ** 2:.1f} MB"
#     file_size_display.short_description = "Size"


@admin.register(EncryptedImage)
class EncryptedImageAdmin(admin.ModelAdmin):
    list_display = [
        "user", "original_name", "image_type", "image_size_display",
        "access_count", "upload_date", "last_accessed",
    ]
    list_filter = ["image_type"]
    search_fields = ["user__email", "original_name", "encrypted_name"]
    ordering = ["-upload_date"]
    readonly_fields = [
        "encrypted_name", "upload_date", "access_count", "last_accessed",
        "encrypted_aes_key", "key_wrap_nonce", "key_wrap_tag",
        "file_nonce", "file_tag",
    ]
    date_hierarchy = "upload_date"

    fieldsets = [
        ("Image info", {"fields": ["user", "original_name", "encrypted_name", "image_type", "image_size"]}),
        ("Usage", {"fields": ["access_count", "last_accessed", "upload_date"]}),
        ("Crypto fields (read-only)", {
            "fields": ["encrypted_aes_key", "key_wrap_nonce", "key_wrap_tag", "file_nonce", "file_tag"],
            "classes": ["collapse"],
        }),
    ]

    def image_size_display(self, obj):
        size = obj.image_size
        if size < 1024:
            return f"{size} B"
        elif size < 1024 ** 2:
            return f"{size / 1024:.1f} KB"
        else:
            return f"{size / 1024 ** 2:.1f} MB"
    image_size_display.short_description = "Size"


# ---------------------------------------------------------------------------
# Access logs
# ---------------------------------------------------------------------------

@admin.register(FileAccessLog)
class FileAccessLogAdmin(admin.ModelAdmin):
    list_display = [
        "user", "file", "action", "ip_address",
        "city", "country", "is_suspicious", "threat_level", "access_time",
    ]
    list_filter = ["action", "is_suspicious", "threat_level", "country"]
    search_fields = ["user__email", "ip_address", "file__original_name", "city", "country"]
    ordering = ["-access_time"]
    readonly_fields = ["access_time"]
    date_hierarchy = "access_time"


@admin.register(ImageAccessLog)
class ImageAccessLogAdmin(admin.ModelAdmin):
    list_display = [
        "user", "image", "action", "ip_address",
        "city", "country", "is_suspicious", "threat_level", "access_time",
    ]
    list_filter = ["action", "is_suspicious", "threat_level", "country"]
    search_fields = ["user__email", "ip_address", "image__original_name", "city", "country"]
    ordering = ["-access_time"]
    readonly_fields = ["access_time"]
    date_hierarchy = "access_time"


# ---------------------------------------------------------------------------
# Shared resources
# ---------------------------------------------------------------------------

@admin.register(SharedFileResource)
class SharedFileResourceAdmin(admin.ModelAdmin):
    list_display = [
        "id", "creator", "resource_type", "is_used",
        "viewer_ip", "created_at", "expires_at", "recipient",
    ]
    list_filter = ["resource_type", "is_used"]
    search_fields = ["creator__email", "viewer_ip", "recipient__email"]
    ordering = ["-created_at"]
    readonly_fields = [
        "id", "created_at", "sender_signature", "payload_hash",
        "recipient_key_fingerprint",
    ]
    date_hierarchy = "created_at"

    fieldsets = [
        ("Resource", {"fields": ["id", "resource_type", "file", "image"]}),
        ("Access control", {
            "fields": ["creator", "recipient", "recipient_key_fingerprint",
                       "allowed_ips", "is_used", "viewer_ip"],
        }),
        ("Expiry", {"fields": ["created_at", "expires_at"]}),
        ("Signature (read-only)", {
            "fields": ["sender_signature", "payload_hash"],
            "classes": ["collapse"],
        }),
    ]

    actions = ["revoke_links"]

    @admin.action(description="Revoke selected share links immediately")
    def revoke_links(self, request, queryset):
        queryset.update(is_used=True, expires_at=timezone.now())
        self.message_user(request, f"{queryset.count()} link(s) revoked.")


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

@admin.register(SecurityNotification)
class SecurityNotificationAdmin(admin.ModelAdmin):
    list_display = [
        "user", "notification_type", "title",
        "email_sent", "is_read", "sent_at", "read_at",
    ]
    list_filter = ["notification_type", "email_sent", "is_read"]
    search_fields = ["user__email", "title", "message"]
    ordering = ["-sent_at"]
    readonly_fields = ["sent_at", "email_sent_at", "read_at"]
    date_hierarchy = "sent_at"


# ---------------------------------------------------------------------------
# P2P rooms & file transfer
# ---------------------------------------------------------------------------

@admin.register(Room)
class RoomAdmin(admin.ModelAdmin):
    list_display = [
        "name", "owner", "passcode", "is_active",
        "max_peers", "peer_count", "created_at",
    ]
    list_filter = ["is_active"]
    search_fields = ["name", "owner__email", "passcode"]
    ordering = ["-created_at"]
    readonly_fields = ["id", "created_at", "passcode"]

    actions = ["deactivate_rooms"]

    @admin.action(description="Deactivate selected rooms")
    def deactivate_rooms(self, request, queryset):
        queryset.update(is_active=False)
        self.message_user(request, f"{queryset.count()} room(s) deactivated.")

    def peer_count(self, obj):
        return obj.peers.filter(is_connected=True).count()
    peer_count.short_description = "Active peers"


@admin.register(Peer)
class PeerAdmin(admin.ModelAdmin):
    list_display = [
        "peer_id", "user", "room", "device_name",
        "is_authenticated", "is_connected", "joined_at", "last_seen",
    ]
    list_filter = ["is_authenticated", "is_connected"]
    search_fields = ["user__email", "peer_id", "device_name", "room__name"]
    ordering = ["-joined_at"]
    readonly_fields = ["joined_at", "last_seen"]


@admin.register(FileTransfer)
class FileTransferAdmin(admin.ModelAdmin):
    list_display = [
        "id", "sender", "receiver", "file_name", "file_type",
        "file_size_display", "status", "progress_display",
        "transfer_speed", "created_at", "completed_at",
    ]
    list_filter = ["status", "file_type"]
    search_fields = ["sender__email", "receiver__email", "file_name"]
    ordering = ["-created_at"]
    readonly_fields = [
        "id", "created_at", "completed_at", "progress_display",
        "encrypted_aes_key", "file_nonce", "file_tag",
        "sender_signature", "payload_hash",
    ]
    date_hierarchy = "created_at"

    fieldsets = [
        ("Transfer info", {
            "fields": ["id", "sender", "receiver", "room", "file",
                       "file_name", "file_type", "file_size", "status"],
        }),
        ("Progress", {
            "fields": ["chunk_count", "chunks_received", "last_chunk_index",
                       "progress_display", "transfer_speed"],
        }),
        ("Key exchange (read-only)", {
            "fields": ["sender_public_key", "receiver_public_key",
                       "encrypted_aes_key", "file_nonce", "file_tag"],
            "classes": ["collapse"],
        }),
        ("Signature (read-only)", {
            "fields": ["sender_signature", "payload_hash"],
            "classes": ["collapse"],
        }),
        ("Timestamps", {"fields": ["created_at", "completed_at"]}),
    ]

    actions = ["mark_failed"]

    @admin.action(description="Mark selected transfers as failed")
    def mark_failed(self, request, queryset):
        queryset.update(status='failed')
        self.message_user(request, f"{queryset.count()} transfer(s) marked as failed.")

    def file_size_display(self, obj):
        size = obj.file_size
        if size < 1024:
            return f"{size} B"
        elif size < 1024 ** 2:
            return f"{size / 1024:.1f} KB"
        else:
            return f"{size / 1024 ** 2:.1f} MB"
    file_size_display.short_description = "Size"

    def progress_display(self, obj):
        return f"{obj.progress()}%"
    progress_display.short_description = "Progress"


# ---------------------------------------------------------------------------
# Admin site branding
# ---------------------------------------------------------------------------

admin.site.site_header = "SecuredVault Administration"
admin.site.site_title = "SecuredVault Admin"
admin.site.index_title = "Security & Vault Management"