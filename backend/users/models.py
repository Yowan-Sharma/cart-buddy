from decimal import Decimal
from django.db import models
from django.contrib.auth.models import AbstractUser



class User(AbstractUser):
    email = models.CharField(max_length=50, unique=True, null=False, blank=False)
    phone = models.BigIntegerField(null=True, blank=True)
    gender = models.CharField(choices=(("Female", "Female"), ("Male", "Male")), null=True, blank=True)
    organisation = models.ForeignKey('organisations.Organisation', on_delete=models.SET_NULL, null=True, blank=True)
    bank_account_number = models.CharField(max_length=20, null=True, blank=True)
    ifsc_code = models.CharField(max_length=11, null=True, blank=True)
    google_id = models.CharField(max_length=128, null=True, blank=True, unique=True)
    pending_penalty = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal("0.00"))
