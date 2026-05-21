import hashlib
import json
import logging
import os
import uuid

from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding as asym_padding
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from django.conf import settings
from django.utils import timezone
from datetime import timedelta  

logger = logging.getLogger(__name__)


def _gcm_encrypt(key: bytes, plaintext: bytes) -> tuple[bytes, bytes, bytes]:
    """
    Encrypt *plaintext* with AES-256-GCM using *key*.

    Returns
    -------
    (ciphertext, nonce, tag)
        nonce  — 12 random bytes, must be stored alongside ciphertext which helps in producing the random counter value on every encryption session.
        tag    — 16-byte authentication tag, must be stored alongside ciphertext
    """
    nonce = get_random_bytes(12)         
    cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
    ciphertext, tag = cipher.encrypt_and_digest(plaintext)
    return ciphertext, nonce, tag


def _gcm_decrypt(
    key: bytes,
    ciphertext: bytes,
    nonce: bytes,
    tag: bytes,
) -> bytes:
    """
    Decrypt *ciphertext* and verify the GCM authentication tag.

    Raises
    ------
    ValueError
        If the tag does not match — data has been tampered with or corrupted.
    """
    # nonce is xored with the keystream produced by the key to produce the cipher text
    cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
    try:
        plaintext = cipher.decrypt_and_verify(ciphertext, tag)
    except ValueError:
        # GCM tag mismatch — ciphertext was modified
        raise ValueError("GCM authentication failed — ciphertext has been tampered with.")
    return plaintext


# ---------------------------------------------------------------------------
# File encryption / decryption  (public API used by views)
# ---------------------------------------------------------------------------

def encrypt_file(file_content: bytes) -> dict:
    """
    Encrypt raw file bytes with AES-256-GCM.

    Returns a dict ready to be unpacked into an EncryptedFile instance:
        {
            'encrypted_aes_key': bytes,
            'key_wrap_nonce':    bytes,
            'key_wrap_tag':      bytes,
            'file_nonce':        bytes,
            'file_tag':          bytes,
            'ciphertext':        bytes,   # write this to disk
        }

    Two separate GCM operations, two independent nonces — never reused.
    """
    master_key: bytes = settings.MASTER_KEY

    # 1. Generate a fresh random AES-256 key for this file
    aes_key = get_random_bytes(32)

    # 2. Encrypt the file content  (nonce A)
    ciphertext, file_nonce, file_tag = _gcm_encrypt(aes_key, file_content)

    # 3. Wrap the AES key with the master key  (nonce B — completely independent)
    encrypted_aes_key, key_wrap_nonce, key_wrap_tag = _gcm_encrypt(master_key, aes_key)

    return {
        'encrypted_aes_key': encrypted_aes_key,
        'key_wrap_nonce':    key_wrap_nonce,
        'key_wrap_tag':      key_wrap_tag,
        'file_nonce':        file_nonce,
        'file_tag':          file_tag,
        'ciphertext':        ciphertext,
    }


def decrypt_file(encrypted_file_obj, request=None) -> bytes:
    """
    Decrypt an EncryptedFile model instance.

    Parameters
    ----------
    encrypted_file_obj : EncryptedFile
        The model instance whose get_file_path() points to the ciphertext on disk.
    request : HttpRequest | None
        If provided, used to log a tampering event when GCM verification fails.

    Raises
    ------
    ValueError
        Propagated from _gcm_decrypt when the GCM tag fails.
    """
    master_key: bytes = settings.MASTER_KEY
    obj = encrypted_file_obj

    # Step 1 — unwrap the AES key (verifies key-wrap tag)
    # first decrypt the key 
    try:
        aes_key = _gcm_decrypt(
            master_key,
            bytes(obj.encrypted_aes_key),
            bytes(obj.key_wrap_nonce),
            bytes(obj.key_wrap_tag),
        )
    except ValueError:
        _handle_tamper_event(obj, request, "Key-wrap GCM tag mismatch")
        raise

    # Step 2 — read ciphertext from disk
    with open(obj.get_file_path(), 'rb') as f:
        ciphertext = f.read()

    # Step 3 — decrypt and verify file content (verifies file tag)
    try:
        plaintext = _gcm_decrypt(
            aes_key,
            ciphertext,
            bytes(obj.file_nonce),
            bytes(obj.file_tag),
        )
    except ValueError:
        _handle_tamper_event(obj, request, "File-content GCM tag mismatch")
        raise

    return plaintext


def encrypt_image(image_content: bytes) -> dict:
    """Identical to encrypt_file — kept separate for semantic clarity."""
    return encrypt_file(image_content)


def decrypt_image(encrypted_image_obj, request=None) -> bytes:
    """
    Decrypt an EncryptedImage model instance.
    Same logic as decrypt_file — delegates to _gcm_decrypt with correct fields.
    """
    master_key: bytes = settings.MASTER_KEY
    obj = encrypted_image_obj

    try:
        aes_key = _gcm_decrypt(
            master_key,
            bytes(obj.encrypted_aes_key),
            bytes(obj.key_wrap_nonce),
            bytes(obj.key_wrap_tag),
        )
    except ValueError:
        _handle_tamper_event(obj, request, "Key-wrap GCM tag mismatch (image)")
        raise

    with open(obj.get_image_path(), 'rb') as f:
        ciphertext = f.read()

    try:
        plaintext = _gcm_decrypt(
            aes_key,
            ciphertext,
            bytes(obj.file_nonce),
            bytes(obj.file_tag),
        )
    except ValueError:
        _handle_tamper_event(obj, request, "Image-content GCM tag mismatch")
        raise

    return plaintext


def _handle_tamper_event(obj, request, reason: str):
    """
    Log a CRITICAL tampering_detected event when GCM verification fails.
    Called internally — never raises, so it never masks the original error.
    """
    try:
        from .models import SuspiciousActivityLog  # local import avoids circular deps

        user = getattr(obj, 'user', None)
        if user is None:
            return

        ip = get_client_ip(request) if request else 'unknown'

        SuspiciousActivityLog.objects.create(
            user=user,
            activity_type='tampering_detected',
            threat_level='CRITICAL',
            ip_address=ip if ip != 'unknown' else None,
            details={
                'reason': reason,
                'object_type': type(obj).__name__,
                'object_id': str(obj.pk),
                'encrypted_name': getattr(obj, 'encrypted_name', ''),
            },
            risk_score=100,
            action_taken='notified',
        )
        logger.critical(
            "TAMPERING DETECTED | user=%s | object=%s pk=%s | reason=%s",
            user.email, type(obj).__name__, obj.pk, reason,
        )
    except Exception as exc:
        logger.error("Failed to log tamper event: %s", exc)


# ---------------------------------------------------------------------------
# Encrypted file / image name generation
# ---------------------------------------------------------------------------

def generate_encrypted_file_name(original_name: str) -> str:
    """Return a random filename preserving the original extension."""
    _, ext = os.path.splitext(original_name)
    return f"enc_{get_random_bytes(16).hex()}{ext}"


def generate_encrypted_image_path(original_name: str) -> str:
    """Return a random path token for an encrypted image (no extension leak)."""
    return f"enc_{get_random_bytes(16).hex()}"


# ---------------------------------------------------------------------------
# Digital signatures  (impersonation prevention)
# ---------------------------------------------------------------------------
# for sharing the file or lets say to prevent the impersonation issue here i am encrypting the data that the user want to share also i have to sign this in digital signature with the sender private key so that no one can spoof between the sender and receiver.

def sign_payload(private_key_pem: bytes, payload: bytes) -> bytes:
    """
    Sign *payload* with an Ed25519 private key.

    Parameters
    ----------
    private_key_pem : bytes
        PEM-encoded Ed25519 private key (password=None assumed — caller
        should decrypt it first if it is stored encrypted).
    payload : bytes
        Typically SHA-256(file_content + sender_id + timestamp).

    Returns
    -------
    bytes
        64-byte Ed25519 signature.
    """
    # convert the pem_key into more useful private key object in python.
    private_key = serialization.load_pem_private_key(
        private_key_pem, password=None, backend=default_backend(),
    )
    # payload is not the data only it contains data, timestamp and at last the sender_id who has sent the data this .sign() is where Ed25519 algorithm is used to encrypt the data.
    return private_key.sign(payload)

# to verify the sign we need the public key of the sender we want signature 
# steps:
'''
YOUR SIDE (before sending to Shyam)
─────────────────────────────────────────────────────

file_content = b"<raw file bytes>"
sender_id    = 42
timestamp    = "2026-04-11T10:30:00Z"

Step 1 — build the payload
    file_hash = sha256(file_content)          → "a3f92b7c..."
    raw       = "a3f92b7c...:42:2026-04-...".encode()
    payload   = sha256(raw)                   → 32 bytes

Step 2 — sign it with YOUR private key
    signature = sign(payload, your_private_key) → 64 bytes

Step 3 — encrypt file + embed signature
    encrypted_package = {
        ciphertext  : AES-GCM(file, shyams_public_key),
        signature   : 64 bytes  ← proves you sent it
        sender_id   : 42        ← so Shyam knows whose public key to fetch
        timestamp   : "2026-..." ← baked into what you signed
    }


SHYAM'S SIDE (after receiving)
─────────────────────────────────────────────────────

Step 4 — Shyam decrypts with his private key
    file_content = decrypt(ciphertext, shyams_private_key)

Step 5 — Shyam rebuilds the EXACT same payload
    file_hash = sha256(file_content)          → must match what you hashed
    raw       = "a3f92b7c...:42:2026-...".encode()
    payload   = sha256(raw)                   → same 32 bytes as yours

Step 6 — Shyam verifies using YOUR public key
    result = verify(your_public_key, signature, payload)

    True  → file unchanged + genuinely from you → ACCEPT
    False → file tampered OR impersonation attempt → BLOCK + alert
'''

def verify_signature(public_key_pem: bytes, signature: bytes, payload: bytes) -> bool:
    """
    Verify an Ed25519 signature.

    Returns True if valid, False if the signature does not match
    (meaning the file was not sent by the claimed sender).
    """
    from cryptography.exceptions import InvalidSignature
    # conver the pem style public key to useful one 
    public_key = serialization.load_pem_public_key(
        public_key_pem, backend=default_backend(),
    )
    try:
        public_key.verify(signature, payload)
        return True
    except InvalidSignature:
        return False


def build_transfer_payload(file_content: bytes, sender_id: int, timestamp: str) -> bytes:
    """
    Build the canonical payload that the sender signs and the receiver verifies.
    Includes file hash + sender identity + timestamp to prevent replay attacks.
    """
    file_hash = hashlib.sha256(file_content).hexdigest()
    raw = f"{file_hash}:{sender_id}:{timestamp}".encode()
    return hashlib.sha256(raw).digest()


# ---------------------------------------------------------------------------
# RSA key operations  (for FileTransfer — wrapping the session AES key)
# ---------------------------------------------------------------------------
# rsa is used to encrypt the aes key previously we used master key but master key is used to encrypt aes key only when i am doing like database encryption or same system transfer but now since i am sharing the file so in this scenario rsa encrypt is used to share the public and private key.
def rsa_encrypt_key(aes_key: bytes, recipient_public_key_pem: str) -> bytes:
    """Encrypt an AES key with the recipient's RSA public key (OAEP/SHA-256)."""
    public_key = serialization.load_pem_public_key(
        recipient_public_key_pem.encode(), backend=default_backend(),
    )
    return public_key.encrypt(
        aes_key,
        asym_padding.OAEP(
            mgf=asym_padding.MGF1(algorithm=hashes.SHA256()),
            algorithm=hashes.SHA256(),
            label=None,
        ),
    )


def rsa_decrypt_key(encrypted_aes_key: bytes, recipient_private_key_pem: str) -> bytes:
    """Decrypt an RSA-wrapped AES key using the recipient's private key."""
    private_key = serialization.load_pem_private_key(
        recipient_private_key_pem.encode(),
        password=None,
        backend=default_backend(),
    )
    return private_key.decrypt(
        encrypted_aes_key,
        asym_padding.OAEP(
            mgf=asym_padding.MGF1(algorithm=hashes.SHA256()),
            algorithm=hashes.SHA256(),
            label=None,
        ),
    )


# ---------------------------------------------------------------------------
# Network / request utilities
# ---------------------------------------------------------------------------

def get_client_ip(request) -> str:
    """Return the real client IP, respecting X-Forwarded-For from trusted proxies."""
    # 1. Check if the mobile app explicitly sent its public IP (for local testing)
    custom_public_ip = request.META.get('HTTP_X_PUBLIC_IP')
    if custom_public_ip:
        return custom_public_ip.strip()

    # 2. Check standard proxy headers
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        # Take the leftmost IP — that's the original client
        return x_forwarded_for.split(',')[0].strip()
        
    # 3. Fallback to the direct connection IP
    return request.META.get('REMOTE_ADDR', '')


def generate_device_fingerprint(request) -> str:
    """
    Derive a stable fingerprint from request headers.
    Not a substitute for a proper device ID from the Flutter app, but
    useful as a server-side consistency check.
    """
    try:
        raw = "".join([
            request.META.get('HTTP_USER_AGENT', ''),
            request.META.get('HTTP_ACCEPT_LANGUAGE', ''),
            request.META.get('HTTP_ACCEPT_ENCODING', ''),
            get_client_ip(request),
        ])
        return hashlib.sha256(raw.encode()).hexdigest()
    except Exception as exc:
        logger.warning("Device fingerprint generation failed: %s", exc)
        return str(uuid.uuid4())


def is_access_time_allowed(request) -> bool:
    """
    Return False if the current hour falls outside ALLOWED_ACCESS_HOURS
    in the **user's local timezone** (resolved from their latest geolocation).
    Setting is optional — if absent, all hours are allowed.
    """
    import pytz

    try:
        if settings.DEBUG:
            return True
        if not hasattr(settings, 'ALLOWED_ACCESS_HOURS'):
            return True
        start, end = settings.ALLOWED_ACCESS_HOURS

        # Resolve the user's real timezone from their latest location record
        user_tz_name = settings.TIME_ZONE
        if hasattr(request, 'user') and request.user.is_authenticated:
            from api.models import UserLocation
            latest = (
                UserLocation.objects
                .filter(user=request.user, timezone__isnull=False)
                .exclude(timezone='')
                .order_by('-last_seen')
                .first()
            )
            if latest and latest.timezone:
                user_tz_name = latest.timezone

        try:
            tz = pytz.timezone(user_tz_name)
        except pytz.UnknownTimeZoneError:
            tz = pytz.timezone(settings.TIME_ZONE)

        local_hour = timezone.now().astimezone(tz).hour
        return start <= local_hour < end
    except Exception as exc:
        logger.error("Access time check failed: %s", exc)
        return True


# ---------------------------------------------------------------------------
# Security logging helpers
# ---------------------------------------------------------------------------

def log_suspicious_activity(
    user,
    activity_type: str,
    threat_level: str,
    request,
    details: dict | None = None,
    risk_score: int = 0,
):
    """Persist a SuspiciousActivityLog row. Never raises."""
    try:
        from .models import SuspiciousActivityLog

        SuspiciousActivityLog.objects.create(
            user=user,
            activity_type=activity_type,
            threat_level=threat_level,
            ip_address=get_client_ip(request) or None,
            details=details or {},
            risk_score=risk_score,
        )
    except Exception as exc:
        logger.error("Failed to log suspicious activity: %s", exc)


def temporarily_block_user(user, reason: str, duration_minutes: int = 30) -> bool:
    """Set blocked_until on the user model. Returns True on success."""
    try:
        user.blocked_until = timezone.now() + timedelta(minutes=duration_minutes)
        user.blocked_reason = reason
        user.save(update_fields=['blocked_until', 'blocked_reason'])
        return True
    except Exception as exc:
        logger.error("Failed to block user %s: %s", user.email, exc)
        return False


def send_security_notification(
    user,
    notification_type: str,
    context: dict | None = None,
) -> bool:
    """Create a SecurityNotification row. Returns True on success."""
    try:
        from .models import SecurityNotification

        MESSAGES = {
            'account_locked': (
                'Account locked',
                'Your account has been temporarily locked due to suspicious activity.',
            ),
            'new_device': (
                'New device detected',
                'A new device has been used to access your account.',
            ),
            'tampering_detected': (
                'Data integrity alert',
                'A file in your vault failed its integrity check. '
                'This may indicate tampering or storage corruption. '
                'Please contact support immediately.',
            ),
            'location_change': (
                'New location detected',
                'Your account was accessed from a new location.',
            ),
            'unusual_access': (
                'Unusual access time',
                'Your account was accessed outside your normal hours.',
            ),
        }

        if notification_type not in MESSAGES:
            logger.warning("Unknown notification type: %s", notification_type)
            return False

        title, message = MESSAGES[notification_type]

        SecurityNotification.objects.create(
            user=user,
            notification_type=notification_type,
            title=title,
            message=message,
            is_read=False,
        )
        return True
    except Exception as exc:
        logger.error("Failed to send security notification: %s", exc)
        return False