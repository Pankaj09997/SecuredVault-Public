from rest_framework.throttling import AnonRateThrottle, UserRateThrottle

class LoginThrottle(AnonRateThrottle):
    scope = 'login'

class OTPThrottle(AnonRateThrottle):
    scope = 'otp'

class BurstThrottle(UserRateThrottle):
    scope = 'burst'

from rest_framework.throttling import SimpleRateThrottle

class SharedResourceViewThrottle(SimpleRateThrottle):
    scope = 'shared_resource'

    def get_cache_key(self, request, view):
        return self.cache_format % {
            'scope': self.scope,
            'ident': self.get_ident(request)
        }