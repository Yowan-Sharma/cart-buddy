from django.urls import path

from .views import OrderChatMessageListCreateView


urlpatterns = [
    path("orders/<int:order_id>/messages/", OrderChatMessageListCreateView.as_view(), name="order_chat_messages"),
]
