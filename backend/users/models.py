from django.db import models
from django.contrib.auth.models import AbstractUser



class User(AbstractUser):
    email= models.CharField(max_length=50, unique=True, null=False, blank=False)
    phone = models.BigIntegerField(null=False, blank=False)
    gender=models.CharField(choices=(("Female","Female"),("Male","Male")),null=False)
    organisation = models.ForeignKey('organisations.Organisation', on_delete=models.SET_NULL, null=True, blank=True)
    bank_account_number = models.CharField(max_length=20, null=True, blank=True)
    ifsc_code = models.CharField(max_length=11, null=True, blank=True)
