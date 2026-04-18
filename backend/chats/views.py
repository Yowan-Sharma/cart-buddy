from django.shortcuts import get_object_or_404
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from orders.models import Order

from .models import ChatMessageType, OrderChatMessage
from .permissions import can_access_order_chat
from .serializers import OrderChatMessageSerializer, SendChatMessageSerializer


class OrderChatMessageListCreateView(generics.GenericAPIView):
	permission_classes = [IsAuthenticated]
	serializer_class = SendChatMessageSerializer

	def get_order(self):
		return get_object_or_404(Order, pk=self.kwargs["order_id"])

	def get(self, request, order_id):
		order = self.get_order()
		if not can_access_order_chat(order=order, user=request.user):
			return Response({"error": "You do not have access to this order chat."}, status=status.HTTP_403_FORBIDDEN)

		limit = int(request.query_params.get("limit", 50))
		before_id = request.query_params.get("before_id")

		queryset = OrderChatMessage.objects.filter(order=order).select_related("sender")
		if before_id:
			queryset = queryset.filter(id__lt=before_id)

		messages = queryset.order_by("-id")[: max(1, min(limit, 200))]
		payload = OrderChatMessageSerializer(messages[::-1], many=True).data
		return Response(payload, status=status.HTTP_200_OK)

	def post(self, request, order_id):
		order = self.get_order()
		if not can_access_order_chat(order=order, user=request.user):
			return Response({"error": "You do not have access to this order chat."}, status=status.HTTP_403_FORBIDDEN)

		serializer = self.get_serializer(data=request.data)
		serializer.is_valid(raise_exception=True)

		chat_message = OrderChatMessage.objects.create(
			order=order,
			sender=request.user,
			message_type=ChatMessageType.TEXT,
			message=serializer.validated_data["message"],
			metadata=serializer.validated_data.get("metadata", {}),
		)
		response_data = OrderChatMessageSerializer(chat_message).data
		return Response(response_data, status=status.HTTP_201_CREATED)
