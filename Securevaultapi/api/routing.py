# api/routing.py
from django.urls import re_path
from api import consumers

websocket_urlpatterns = [
    re_path(r'^ws/signaling/(?P<room_id>[^/]+)/$', consumers.SignalingConsumer.as_asgi()),
]