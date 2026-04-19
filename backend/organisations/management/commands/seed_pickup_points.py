from django.core.management.base import BaseCommand

from organisations.models import Campus, Organisation, PickupPoint


class Command(BaseCommand):
	help = "Seed standard pickup points for all organisations."

	def handle(self, *args, **options):
		created_count = 0
		standard_points = [
			("Main Gate", "Primary pickup point near the main entrance."),
			("Central Library", "Easy-to-find pickup spot near the library entrance."),
			("Student Center", "Common student meetup area for quick handoffs."),
			("Hostel A Gate", "Convenient spot for residents near Hostel A."),
			("Sports Complex", "Pickup point near the athletic facilities."),
			("Cafeteria", "Busy area near the main food court."),
		]

		for organisation in Organisation.objects.all():
			campus = (
				Campus.objects.filter(organisation=organisation, is_active=True)
				.order_by("name")
				.first()
			)

			for index, (name, description) in enumerate(standard_points, start=1):
				point, created = PickupPoint.objects.get_or_create(
					organisation=organisation,
					name=name,
					defaults={
						"campus": campus,
						"description": description,
						"sort_order": index,
					},
				)
				if created:
					created_count += 1

			self.stdout.write(
				self.style.SUCCESS(
					f"Ensured standard points exist for {organisation.name}."
				)
			)

		self.stdout.write(
			self.style.SUCCESS(f"Done. Created {created_count} new pickup points.")
		)
