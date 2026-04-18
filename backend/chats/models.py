from django.db import models


class ChatMessageType(models.TextChoices):
	TEXT = "TEXT", "Text"
	SYSTEM = "SYSTEM", "System"


class OrderChatMessage(models.Model):
	order = models.ForeignKey("orders.Order", on_delete=models.CASCADE, related_name="chat_messages")
	sender = models.ForeignKey("users.User", on_delete=models.CASCADE, related_name="sent_chat_messages")
	message_type = models.CharField(max_length=10, choices=ChatMessageType.choices, default=ChatMessageType.TEXT)
	message = models.TextField()
	metadata = models.JSONField(default=dict, blank=True)
	created_at = models.DateTimeField(auto_now_add=True)

	class Meta:
		ordering = ["created_at", "id"]
		indexes = [
			models.Index(fields=["order", "created_at"]),
			models.Index(fields=["sender", "created_at"]),
		]

	def __str__(self):
		return f"Order #{self.order_id} chat by user #{self.sender_id}"
