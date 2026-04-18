from django.db import models
from django.contrib.auth.models import AbstractUser


HOSTEL_CHOICES = [
    ("A", "A"),("B","B"),("C", "C"),("D", "D")
]

class User(AbstractUser):
    email= models.CharField(max_length=50, unique=True, null=False, blank=False)
    phone = models.BigIntegerField(null=False, blank=False)
    hostel = models.CharField(choices=HOSTEL_CHOICES,null=False, blank=False)
    gender=models.CharField(choices=(("Female","Female"),("Male","Male")),null=False)
    organisation = models.CharField(max_length=100, null=True, blank=True)