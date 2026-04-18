from django.urls import re_path

from .consumers import OrderChatConsumer


websocket_urlpatterns = [
    re_path(r"^ws/chats/orders/(?P<order_id>\d+)/$", OrderChatConsumer.as_asgi()),
]
