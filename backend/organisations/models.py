from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.utils.text import slugify


class MembershipRole(models.TextChoices):
	OWNER = "OWNER", "Owner"
	ADMIN = "ADMIN", "Admin"
	STAFF = "STAFF", "Staff"
	MEMBER = "MEMBER", "Member"


class MembershipStatus(models.TextChoices):
	INVITED = "INVITED", "Invited"
	ACTIVE = "ACTIVE", "Active"
	SUSPENDED = "SUSPENDED", "Suspended"
	LEFT = "LEFT", "Left"


class Organisation(models.Model):
	name = models.CharField(max_length=120, unique=True)
	slug = models.SlugField(max_length=140, unique=True, blank=True)
	short_code = models.CharField(max_length=20, unique=True)
	domain = models.CharField(max_length=120, blank=True)
	is_active = models.BooleanField(default=True)
	metadata = models.JSONField(default=dict, blank=True)
	created_at = models.DateTimeField(auto_now_add=True)
	updated_at = models.DateTimeField(auto_now=True)

	class Meta:
		ordering = ["name"]
		indexes = [
			models.Index(fields=["slug"]),
			models.Index(fields=["short_code"]),
			models.Index(fields=["is_active"]),
		]

	def __str__(self) -> str:
		return self.name

	def save(self, *args, **kwargs):
		if not self.slug:
			self.slug = slugify(self.name)
		super().save(*args, **kwargs)


class Campus(models.Model):
	organisation = models.ForeignKey(
		Organisation,
		on_delete=models.CASCADE,
		related_name="campuses",
	)
	name = models.CharField(max_length=120)
	slug = models.SlugField(max_length=140, blank=True)
	city = models.CharField(max_length=80, blank=True)
	state = models.CharField(max_length=80, blank=True)
	country = models.CharField(max_length=80, default="India")
	is_active = models.BooleanField(default=True)
	metadata = models.JSONField(default=dict, blank=True)
	created_at = models.DateTimeField(auto_now_add=True)
	updated_at = models.DateTimeField(auto_now=True)

	class Meta:
		ordering = ["organisation__name", "name"]
		constraints = [
			models.UniqueConstraint(
				fields=["organisation", "slug"],
				name="organisations_campus_unique_org_slug",
			),
		]
		indexes = [
			models.Index(fields=["organisation", "is_active"]),
		]

	def __str__(self) -> str:
		return f"{self.organisation.short_code} - {self.name}"

	def save(self, *args, **kwargs):
		if not self.slug:
			self.slug = slugify(self.name)
		super().save(*args, **kwargs)


class OrganisationMembership(models.Model):
	organisation = models.ForeignKey(
		Organisation,
		on_delete=models.CASCADE,
		related_name="memberships",
	)
	user = models.ForeignKey(
		settings.AUTH_USER_MODEL,
		on_delete=models.CASCADE,
		related_name="organisation_memberships",
	)
	role = models.CharField(
		max_length=10,
		choices=MembershipRole.choices,
		default=MembershipRole.MEMBER,
	)
	status = models.CharField(
		max_length=12,
		choices=MembershipStatus.choices,
		default=MembershipStatus.ACTIVE,
	)
	joined_at = models.DateTimeField(auto_now_add=True)
	left_at = models.DateTimeField(null=True, blank=True)
	created_at = models.DateTimeField(auto_now_add=True)
	updated_at = models.DateTimeField(auto_now=True)

	class Meta:
		ordering = ["organisation__name", "user_id"]
		constraints = [
			models.UniqueConstraint(
				fields=["organisation", "user"],
				name="organisations_membership_unique_org_user",
			),
		]
		indexes = [
			models.Index(fields=["organisation", "role"]),
			models.Index(fields=["organisation", "status"]),
		]

	def __str__(self) -> str:
		return f"{self.user_id} in {self.organisation.short_code} ({self.role})"

	def clean(self):
		if self.left_at and self.status not in [MembershipStatus.LEFT, MembershipStatus.SUSPENDED]:
			raise ValidationError("left_at can only be set when status is LEFT or SUSPENDED.")
