# api/jwtmiddleware.py
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from channels.db import database_sync_to_async
from api.models import MyUser  # Changed from relative import to absolute import

class JWTAuthMiddleware:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        query_string = scope.get("query_string", b"").decode("utf-8")
        token_param = [param.split("=") for param in query_string.split("&") if param.startswith("token=")]
        
        token = token_param[0][1] if token_param and len(token_param[0]) > 1 else None
        
        if token:
            try:
                access_token = AccessToken(token)
                user = await self.get_user(access_token)
                scope['user'] = user
            except (InvalidToken, TokenError):
                scope['user'] = AnonymousUser()
        else:
            scope['user'] = AnonymousUser()
        
        return await self.app(scope, receive, send)

    @database_sync_to_async
    def get_user(self, access_token):
        user_id = access_token['user_id']
        return MyUser.objects.get(id=user_id)