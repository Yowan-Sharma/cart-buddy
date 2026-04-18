from rest_framework import generics
from rest_framework.permissions import IsAuthenticated

from .models import (
	Campus,
	MembershipRole,
	MembershipStatus,
	Organisation,
	OrganisationMembership,
)
from .serializers import CampusSerializer, OrganisationMembershipSerializer, OrganisationSerializer


class IsOrganisationAdmin(IsAuthenticated):
	"""Allow only active org owner/admin/staff members for write operations."""

	allowed_roles = [MembershipRole.OWNER, MembershipRole.ADMIN, MembershipRole.STAFF]

	def has_permission(self, request, view):
		if request.method in ["GET", "HEAD", "OPTIONS"]:
			return super().has_permission(request, view)
		if not super().has_permission(request, view):
			return False
		if getattr(view, "kwargs", {}).get("pk"):
			# Detail routes rely on object-level permission checks.
			return True

		org_id = request.data.get("organisation") or request.query_params.get("organisation")

		if not org_id:
			return False

		return self._is_org_admin(request.user.id, org_id)

	def has_object_permission(self, request, view, obj):
		if request.method in ["GET", "HEAD", "OPTIONS"]:
			return request.user and request.user.is_authenticated
		org_id = getattr(obj, "organisation_id", None) or getattr(obj, "id", None)
		if not org_id:
			return False
		return self._is_org_admin(request.user.id, org_id)

	def _is_org_admin(self, user_id, org_id):
		if not org_id:
			return False
		from django.contrib.auth import get_user_model
		User = get_user_model()
		if User.objects.filter(id=user_id, is_superuser=True).exists():
			return True

		return OrganisationMembership.objects.filter(
			organisation_id=org_id,
			user_id=user_id,
			role__in=self.allowed_roles,
			status=MembershipStatus.ACTIVE,
		).exists()


class OrganisationListCreateView(generics.ListCreateAPIView):
	queryset = Organisation.objects.all()
	serializer_class = OrganisationSerializer
	permission_classes = [IsOrganisationAdmin]

	def get_queryset(self):
		if self.request.method == "GET":
			return Organisation.objects.all()
		if self.request.user.is_superuser:
			return self.queryset
		return self.queryset.filter(
			memberships__user=self.request.user,
			memberships__status=MembershipStatus.ACTIVE,
		).distinct()

	def get_permissions(self):
		if self.request.method == "GET":
			return [IsAuthenticated()]
		if self.request.method == "POST":
			return [IsAuthenticated()]
		return [permission() for permission in self.permission_classes]

	def perform_create(self, serializer):
		organisation = serializer.save()
		OrganisationMembership.objects.create(
			organisation=organisation,
			user=self.request.user,
			role=MembershipRole.OWNER,
			status=MembershipStatus.ACTIVE,
		)


class OrganisationDetailView(generics.RetrieveUpdateDestroyAPIView):
	queryset = Organisation.objects.all()
	serializer_class = OrganisationSerializer
	permission_classes = [IsOrganisationAdmin]

	def get_queryset(self):
		if self.request.user.is_superuser:
			return self.queryset
		return self.queryset.filter(
			memberships__user=self.request.user,
			memberships__status=MembershipStatus.ACTIVE,
		).distinct()


class CampusListCreateView(generics.ListCreateAPIView):
	serializer_class = CampusSerializer
	permission_classes = [IsOrganisationAdmin]

	def get_queryset(self):
		queryset = Campus.objects.select_related("organisation").all()
		if not self.request.user.is_superuser:
			queryset = queryset.filter(
				organisation__memberships__user=self.request.user,
				organisation__memberships__status=MembershipStatus.ACTIVE,
			).distinct()
		org_id = self.request.query_params.get("organisation")
		if org_id:
			queryset = queryset.filter(organisation_id=org_id)
		return queryset


class CampusDetailView(generics.RetrieveUpdateDestroyAPIView):
	queryset = Campus.objects.select_related("organisation").all()
	serializer_class = CampusSerializer
	permission_classes = [IsOrganisationAdmin]

	def get_queryset(self):
		queryset = self.queryset
		if self.request.user.is_superuser:
			return queryset
		return queryset.filter(
			organisation__memberships__user=self.request.user,
			organisation__memberships__status=MembershipStatus.ACTIVE,
		).distinct()


class MembershipListCreateView(generics.ListCreateAPIView):
	serializer_class = OrganisationMembershipSerializer
	permission_classes = [IsOrganisationAdmin]

	def get_queryset(self):
		queryset = OrganisationMembership.objects.select_related("organisation", "user").all()
		if not self.request.user.is_superuser:
			queryset = queryset.filter(
				organisation__memberships__user=self.request.user,
				organisation__memberships__status=MembershipStatus.ACTIVE,
			).distinct()
		org_id = self.request.query_params.get("organisation")
		user_id = self.request.query_params.get("user")
		if org_id:
			queryset = queryset.filter(organisation_id=org_id)
		if user_id:
			queryset = queryset.filter(user_id=user_id)
		return queryset


class MembershipDetailView(generics.RetrieveUpdateDestroyAPIView):
	queryset = OrganisationMembership.objects.select_related("organisation", "user").all()
	serializer_class = OrganisationMembershipSerializer
	permission_classes = [IsOrganisationAdmin]

	def get_queryset(self):
		queryset = self.queryset
		if self.request.user.is_superuser:
			return queryset
		return queryset.filter(
			organisation__memberships__user=self.request.user,
			organisation__memberships__status=MembershipStatus.ACTIVE,
		).distinct()


class MyOrganisationMembershipsView(generics.ListAPIView):
	serializer_class = OrganisationMembershipSerializer
	permission_classes = [IsAuthenticated]

	def get_queryset(self):
		return OrganisationMembership.objects.select_related("organisation", "user").filter(user=self.request.user)
