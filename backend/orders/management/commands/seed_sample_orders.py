"""
Seed development data for the orders app.

Order model (table: orders_order) — main fields used by the list API:
  organisation (FK, nullable), campus (FK, nullable), creator (FK user),
  title, restaurant_name, meeting_point, meeting_notes,
  status (OrderStatus: OPEN, LOCKED, IN_PROGRESS, DELIVERED, COMPLETED, CANCELLED),
  max_participants (>0), currency, subtotal_amount, platform_fee, delivery_fee,
  other_fee, total_amount, cutoff_at (required), expected_delivery_at, etc.

List endpoint: GET /orders/ — filtered by OrganisationFilterBackend to the
request user's organisation. Users without organisation see an empty list.

Creates OPEN orders with cutoff_at in the future and a creator participant row.
"""

from datetime import timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.utils import timezone

from organisations.models import (
	Campus,
	MembershipRole,
	MembershipStatus,
	Organisation,
	OrganisationMembership,
)
from orders.models import (
	Order,
	OrderParticipant,
	OrderStatus,
	ParticipantRole,
	ParticipantStatus,
)
from users.models import User


class Command(BaseCommand):
	help = "Create sample OPEN orders for a user and their organisation (dev / demos)."

	def add_arguments(self, parser):
		parser.add_argument(
			"--username",
			type=str,
			default=None,
			help="User to use as creator (default: first user with an organisation, else first user).",
		)

	def handle(self, *args, **options):
		username = options["username"]
		if username:
			user = User.objects.filter(username=username).first()
			if not user:
				self.stderr.write(self.style.ERROR(f"No user with username={username!r}."))
				return
		else:
			user = User.objects.exclude(organisation__isnull=True).first()
			if not user:
				user = User.objects.order_by("id").first()
				if not user:
					self.stderr.write(self.style.ERROR("No users in the database. Create a user first."))
					return

		org = user.organisation
		if not org:
			org, _ = Organisation.objects.get_or_create(
				short_code="DEMO",
				defaults={"name": "Demo University"},
			)
			user.organisation = org
			user.save(update_fields=["organisation"])
			self.stdout.write(self.style.WARNING(f"Assigned organisation {org.short_code!r} to user {user.username!r}."))

		OrganisationMembership.objects.get_or_create(
			organisation=org,
			user=user,
			defaults={
				"role": MembershipRole.MEMBER,
				"status": MembershipStatus.ACTIVE,
			},
		)

		campus = Campus.objects.filter(organisation=org).first()
		if not campus:
			campus = Campus.objects.create(
				organisation=org,
				name="Main Campus",
				city="Demo City",
			)

		now = timezone.now()
		samples = [
			{
				"title": "[Sample] Domino's dinner run",
				"restaurant_name": "Domino's Pizza",
				"meeting_point": "Hostel Circle",
				"total_amount": Decimal("450.00"),
				"hours_ahead": 2,
			},
			{
				"title": "[Sample] Institute canteen lunch",
				"restaurant_name": "Institute Canteen",
				"meeting_point": "LH Parking",
				"total_amount": Decimal("120.00"),
				"hours_ahead": 3,
			},
		]

		for i, s in enumerate(samples):
			order, created = Order.objects.get_or_create(
				organisation=org,
				creator=user,
				title=s["title"],
				defaults={
					"campus": campus,
					"restaurant_name": s["restaurant_name"],
					"meeting_point": s["meeting_point"],
					"status": OrderStatus.OPEN,
					"max_participants": 6,
					"cutoff_at": now + timedelta(hours=s["hours_ahead"]),
					"subtotal_amount": s["total_amount"],
					"total_amount": s["total_amount"],
				},
			)
			if created:
				OrderParticipant.objects.create(
					order=order,
					user=user,
					role=ParticipantRole.CREATOR,
					status=ParticipantStatus.JOINED,
				)
				self.stdout.write(self.style.SUCCESS(f"Created order #{order.pk}: {order.title}"))
			else:
				self.stdout.write(f"Already exists (skipped): {order.title}")

			OrderParticipant.objects.get_or_create(
				order=order,
				user=user,
				defaults={
					"role": ParticipantRole.CREATOR,
					"status": ParticipantStatus.JOINED,
				},
			)

		self.stdout.write(self.style.SUCCESS(f"Done. Organisation={org.short_code!r} creator={user.username!r}"))
