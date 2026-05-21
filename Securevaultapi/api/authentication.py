"""
Custom JWT authentication that checks the token blacklist on every request.

SimpleJWT's default JWTAuthentication only validates the cryptographic
signature and expiry of access tokens — it does NOT check whether the
underlying refresh token (or the access token's JTI) has been blacklisted.

This means that after a password change (which blacklists all outstanding
tokens), existing access tokens on other devices remain valid until they
naturally expire.

This module solves that by cross‑referencing every incoming access token's
JTI against the BlacklistedToken table, ensuring immediate session
invalidation across all devices.
"""

import datetime
from django.utils import timezone
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import AuthenticationFailed

class BlacklistCheckJWTAuthentication(JWTAuthentication):
    """
    Extends the default JWTAuthentication to reject access tokens
    that were issued before the user last changed their password.
    """

    def get_user(self, validated_token):
        user = super().get_user(validated_token)
        
        if user.password_changed_at:
            iat = validated_token.get("iat")
            if iat:
                # iat is a UTC Unix timestamp
                token_issued_at = datetime.datetime.fromtimestamp(iat, tz=datetime.timezone.utc)
                # If the token was issued BEFORE the password was changed, reject it
                if token_issued_at < user.password_changed_at:
                    raise AuthenticationFailed(
                        "This session has been invalidated because the password was changed. Please log in again."
                    )

        return user
