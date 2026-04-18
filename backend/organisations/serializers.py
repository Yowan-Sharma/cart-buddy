from django.contrib.auth import get_user_model
from rest_framework import serializers

from .models import Campus, Organisation, OrganisationMembership


User = get_user_model()


class OrganisationSerializer(serializers.ModelSerializer):
	class Meta:
		model = Organisation
		fields = [
			"id",
			"name",
			"slug",
			"short_code",
			"domain",
			"is_active",
			"metadata",
			"created_at",
			"updated_at",
		]
		read_only_fields = ["id", "slug", "created_at", "updated_at"]


class CampusSerializer(serializers.ModelSerializer):
	organisation_name = serializers.CharField(source="organisation.name", read_only=True)

	class Meta:
		model = Campus
		fields = [
			"id",
			"organisation",
			"organisation_name",
			"name",
			"slug",
			"city",
			"state",
			"country",
			"is_active",
			"metadata",
			"created_at",
			"updated_at",
		]
		read_only_fields = ["id", "slug", "created_at", "updated_at", "organisation_name"]


class MembershipUserSerializer(serializers.ModelSerializer):
	class Meta:
		model = User
		fields = ["id", "username", "email", "first_name", "last_name"]


class OrganisationMembershipSerializer(serializers.ModelSerializer):
	user_data = MembershipUserSerializer(source="user", read_only=True)
	organisation_name = serializers.CharField(source="organisation.name", read_only=True)

	class Meta:
		model = OrganisationMembership
		fields = [
			"id",
			"organisation",
			"organisation_name",
			"user",
			"user_data",
			"role",
			"status",
			"joined_at",
			"left_at",
			"created_at",
			"updated_at",
		]
		read_only_fields = ["id", "joined_at", "created_at", "updated_at", "organisation_name", "user_data"]