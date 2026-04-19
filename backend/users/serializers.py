from rest_framework import serializers
from .models import User

class UserSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    organisation_name = serializers.CharField(source='organisation.name', read_only=True)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'phone', 'gender', 'organisation', 'organisation_name', 'password', 'bank_account_number', 'ifsc_code']
    
    def create(self, validated_data):
        password = validated_data.pop('password', None)
        organisation = validated_data.get('organisation')
        user = User(**validated_data)
        if password:
            user.set_password(password)
        user.save()
        
        if organisation:
            self._ensure_membership(user, organisation)
        return user

    def update(self, instance, validated_data):
        password = validated_data.pop('password', None)
        organisation = validated_data.get('organisation')
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if password:
            instance.set_password(password)
        instance.save()
        
        if organisation:
            self._ensure_membership(instance, organisation)
        return instance

    def _ensure_membership(self, user, organisation):
        from organisations.models import OrganisationMembership, MembershipRole, MembershipStatus
        OrganisationMembership.objects.get_or_create(
            user=user,
            organisation=organisation,
            defaults={
                'role': MembershipRole.MEMBER,
                'status': MembershipStatus.ACTIVE,
            }
        )
    