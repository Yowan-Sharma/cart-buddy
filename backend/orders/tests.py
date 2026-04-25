from django.test import TestCase
from rest_framework import status
from rest_framework.test import APITestCase

from orders.models import Order, ParticipantRole, ParticipantStatus
from users.models import User


class OrderCreationTests(APITestCase):
	def setUp(self):
		self.creator = User.objects.create_user(
			username="creator_order_test",
			password="Pass@1234",
			email="creator.order@test.com",
			phone=9876543220,
			hostel="A",
			gender="Male",
		)

	def test_creator_participant_is_marked_paid_on_order_create(self):
		self.client.force_authenticate(user=self.creator)
		response = self.client.post(
			"/orders/",
			{
				"title": "Host Order",
				"restaurant_name": "Dominos",
				"meeting_point": "Hostel Gate",
				"base_amount": "50.00",
				"currency": "INR",
			},
			format="json",
		)

		self.assertEqual(response.status_code, status.HTTP_201_CREATED)
		order = Order.objects.get(id=response.data["id"])
		creator_participant = order.participants.get(user=self.creator)

		self.assertEqual(creator_participant.role, ParticipantRole.CREATOR)
		self.assertEqual(str(order.subtotal_amount), "50.00")
		self.assertEqual(str(order.total_amount), "50.00")
		self.assertEqual(str(creator_participant.amount_due), "50.00")
		self.assertEqual(str(creator_participant.amount_paid), "50.00")
		self.assertEqual(creator_participant.status, ParticipantStatus.PAID)
