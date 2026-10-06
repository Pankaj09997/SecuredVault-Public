from rest_framework.throttling import AnonRateThrottle, UserRateThrottle

class LoginThrottle(AnonRateThrottle):
    scope = 'login'

class OTPThrottle(AnonRateThrottle):
    scope = 'otp'

class BurstThrottle(UserRateThrottle):
    scope = 'burst'

class SharedResourceViewThrottle(AnonRateThrottle):
    scope = 'shared_resource'