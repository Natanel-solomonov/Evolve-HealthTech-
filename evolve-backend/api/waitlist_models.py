from django.db import models, transaction
from django.db.models import F, Max
import uuid

__all__ = ["WaitlistedAppUser", "University"]

class University(models.Model):
    name = models.CharField(max_length=255, unique=True)
    aliases = models.JSONField(default=list, blank=True)

    class Meta:
        db_table = "website_university"
        managed = False
        verbose_name_plural = "universities"
        app_label = "api"

    def __str__(self):
        return self.name

class WaitlistedAppUser(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone_number = models.CharField(max_length=20, unique=True)
    first_name = models.CharField(max_length=255, blank=True, null=True)
    last_name = models.CharField(max_length=255, blank=True, null=True)
    school = models.ForeignKey(University, on_delete=models.SET_NULL, null=True, blank=True, related_name='waitlisted_users')
    position = models.IntegerField(unique=True, null=True, default=None)
    referrals = models.IntegerField(default=0)
    referral_link = models.CharField(max_length=50, unique=True, blank=True, null=True)

    class Meta:
        db_table = "website_waitlistedappuser"
        managed = False
        app_label = "api"

    def __str__(self):
        display_name = f"{self.first_name or ''} {self.last_name or ''}".strip() or self.phone_number
        return f"{display_name} - Position: {self.position if self.position is not None else 'N/A'}"

    # retain change_position and save if needed (they don't modify schema)
    def change_position(self, new_position):
        if not self.pk:
            raise ValueError("Cannot change position for an unsaved user. Save the user first.")
        if not isinstance(new_position, int) or new_position < 1:
            raise ValueError("New position must be a positive integer.")
        with transaction.atomic():
            old_position = self.position
            if new_position == old_position:
                return
            count = WaitlistedAppUser.objects.count()
            effective_new_position = max(1, min(new_position, count))
            if effective_new_position == old_position:
                return
            original_pk = self.pk
            WaitlistedAppUser.objects.filter(pk=original_pk).update(position=None)
            if effective_new_position < old_position:
                users_to_shift_qs = WaitlistedAppUser.objects.filter(position__gte=effective_new_position, position__lt=old_position).exclude(pk=original_pk).order_by('-position')
                for u in users_to_shift_qs:
                    WaitlistedAppUser.objects.filter(pk=u.pk).update(position=F('position')+1)
            else:
                users_to_shift_qs = WaitlistedAppUser.objects.filter(position__gt=old_position, position__lte=effective_new_position).exclude(pk=original_pk).order_by('position')
                for u in users_to_shift_qs:
                    WaitlistedAppUser.objects.filter(pk=u.pk).update(position=F('position')-1)
            WaitlistedAppUser.objects.filter(pk=original_pk).update(position=effective_new_position)
            self.refresh_from_db() 