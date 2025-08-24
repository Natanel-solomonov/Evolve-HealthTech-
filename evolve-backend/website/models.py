from django.db import models, transaction
from django.db.models import F, Max
import uuid

class WaitlistedAppUser(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone_number = models.CharField(max_length=20, unique=True)
    first_name = models.CharField(max_length=255, blank=True, null=True)
    last_name = models.CharField(max_length=255, blank=True, null=True)
    school = models.ForeignKey('University', on_delete=models.SET_NULL, null=True, blank=True, related_name='waitlisted_users')
    position = models.IntegerField(unique=True, null=True, default=None)
    referrals = models.IntegerField(default=0)
    referral_link = models.CharField(max_length=50, unique=True, blank=True, null=True)

    def __str__(self):
        display_name = f"{self.first_name or ''} {self.last_name or ''}".strip()
        if not display_name:
            display_name = self.phone_number # Fallback to phone number if no name
        return f"{display_name} - Position: {self.position if self.position is not None else 'N/A'}"

    def save(self, *args, **kwargs):
        is_being_added = self._state.adding

        if is_being_added:
            # If it's a new instance being added:
            # 1. Generate position if not already explicitly set (e.g., by management command)
            if self.position is None:
                max_pos_data = WaitlistedAppUser.objects.aggregate(current_max_pos=Max('position'))
                current_max = max_pos_data['current_max_pos'] if max_pos_data['current_max_pos'] is not None else 0
                self.position = current_max + 1
            
            # 2. Generate referral link if not already set
            if not self.referral_link: # This handles None or an empty string
                self.referral_link = uuid.uuid4().hex[:10]
                # Ensure uniqueness for the generated referral link
                while WaitlistedAppUser.objects.filter(referral_link=self.referral_link).exists():
                    self.referral_link = uuid.uuid4().hex[:10]
        
        super().save(*args, **kwargs) # Call the "real" save method.

    def change_position(self, new_position):
        if not self.pk:
            raise ValueError("Cannot change position for an unsaved user. Save the user first.")

        if not isinstance(new_position, int) or new_position < 1:
            raise ValueError("New position must be a positive integer.")

        with transaction.atomic():
            old_position = self.position

            if new_position == old_position:
                return # No change needed

            count = WaitlistedAppUser.objects.count()
            effective_new_position = max(1, min(new_position, count))

            if effective_new_position == old_position:
                return # No change after clamping

            original_pk = self.pk
            WaitlistedAppUser.objects.filter(pk=original_pk).update(position=None) # Temporarily set to None

            if effective_new_position < old_position: # Moving up the list (e.g., from 10 to 5)
                # Users from effective_new_position to old_position-1 shift down (increment position)
                # Process in descending order of current position to avoid conflicts
                users_to_shift_qs = WaitlistedAppUser.objects.filter(
                    position__gte=effective_new_position,
                    position__lt=old_position
                ).exclude(pk=original_pk).order_by('-position') # Important: 40, then 39, then 38...
                
                for user_in_block in users_to_shift_qs:
                    WaitlistedAppUser.objects.filter(pk=user_in_block.pk).update(position=F('position') + 1)
            
            elif effective_new_position > old_position: # Moving down the list (e.g., from 5 to 10)
                # Users from old_position+1 to effective_new_position shift up (decrement position)
                # Process in ascending order of current position to avoid conflicts
                users_to_shift_qs = WaitlistedAppUser.objects.filter(
                    position__gt=old_position,
                    position__lte=effective_new_position
                ).exclude(pk=original_pk).order_by('position') # Important: old_pos+1, then old_pos+2...
                
                for user_in_block in users_to_shift_qs:
                    WaitlistedAppUser.objects.filter(pk=user_in_block.pk).update(position=F('position') - 1)
            
            # Now, place the user in the new position
            WaitlistedAppUser.objects.filter(pk=original_pk).update(position=effective_new_position)
            self.refresh_from_db()

    def delete(self, *args, **kwargs):
        if self.position is not None: # Only proceed if the user has a position
            position_to_fill = self.position
            
            with transaction.atomic():
                # Proceed with the actual deletion
                super().delete(*args, **kwargs)
                
                # Shift users up who were after the deleted user
                WaitlistedAppUser.objects.filter(position__gt=position_to_fill).update(position=F('position') - 1)
        else:
            # If the user has no position, just delete them normally
            super().delete(*args, **kwargs)

            
class University(models.Model):
    name = models.CharField(max_length=255, unique=True)
    aliases = models.JSONField(default=list, blank=True)

    class Meta:
        verbose_name_plural = "universities"

    def __str__(self):
        return self.name
