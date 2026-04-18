import json

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer

from orders.models import Order

from .models import ChatMessageType, OrderChatMessage
from .permissions import can_access_order_chat


class OrderChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope.get("user")
        order_id = self.scope.get("url_route", {}).get("kwargs", {}).get("order_id")

        if not self.user or not self.user.is_authenticated:
            await self.close(code=4401)
            return

        self.order = await self._get_order(order_id)
        if not self.order:
            await self.close(code=4404)
            return

        has_access = await self._can_access(self.order, self.user)
        if not has_access:
            await self.close(code=4403)
            return

        self.group_name = f"order_chat_{self.order.id}"
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, "group_name"):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        if not text_data:
            return

        try:
            payload = json.loads(text_data)
        except json.JSONDecodeError:
            await self.send(text_data=json.dumps({"type": "error", "error": "Invalid JSON payload."}))
            return

        message = (payload.get("message") or "").strip()
        metadata = payload.get("metadata") or {}

        if not message:
            await self.send(text_data=json.dumps({"type": "error", "error": "message cannot be empty."}))
            return

        chat_message = await self._save_message(order=self.order, sender=self.user, message=message, metadata=metadata)

        await self.channel_layer.group_send(
            self.group_name,
            {
                "type": "chat.message",
                "message": {
                    "id": chat_message.id,
                    "order": self.order.id,
                    "sender": self.user.id,
                    "sender_username": self.user.username,
                    "message_type": chat_message.message_type,
                    "message": chat_message.message,
                    "metadata": chat_message.metadata,
                    "created_at": chat_message.created_at.isoformat(),
                },
            },
        )

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({"type": "chat.message", "data": event["message"]}))

    @database_sync_to_async
    def _get_order(self, order_id):
        try:
            return Order.objects.get(id=order_id)
        except Order.DoesNotExist:
            return None

    @database_sync_to_async
    def _can_access(self, order, user):
        return can_access_order_chat(order=order, user=user)

    @database_sync_to_async
    def _save_message(self, *, order, sender, message, metadata):
        return OrderChatMessage.objects.create(
            order=order,
            sender=sender,
            message_type=ChatMessageType.TEXT,
            message=message,
            metadata=metadata,
        )
