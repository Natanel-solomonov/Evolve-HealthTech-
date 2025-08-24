from django.core.management.base import BaseCommand
from django.db import transaction
from website.models import WaitlistedAppUser # Ensure this import path is correct

class Command(BaseCommand):
    help = 'Reorders all waitlisted users to ensure there are no gaps in their positions.'

    @transaction.atomic
    def handle(self, *args, **options):
        self.stdout.write('Starting to reorder waitlist user positions...')

        # Fetch all users who have a position, ordered by their current position
        users_to_reorder = WaitlistedAppUser.objects.filter(position__isnull=False).order_by('position')

        if not users_to_reorder.exists():
            self.stdout.write(self.style.WARNING('No users found with a position. No reordering needed.'))
            return

        current_position = 1
        users_updated_count = 0

        for user in users_to_reorder:
            if user.position != current_position:
                user.position = current_position
                # We need to save using update_fields to avoid triggering the full save() logic
                # which might have side effects we don't want during a mass reorder,
                # especially if the save() method itself tries to recalculate position.
                # However, given the current save() method assigns position if None, and this script
                # ensures position is *not* None, we can directly set and save.
                # Let's re-evaluate if `user.save(update_fields=['position'])` is better.
                # For now, a direct assignment and then a single update call per user.
                # Actually, it's better to update directly to bypass save() method side-effects if any.
                WaitlistedAppUser.objects.filter(pk=user.pk).update(position=current_position)
                users_updated_count +=1
            current_position += 1
        
        if users_updated_count > 0:
            self.stdout.write(self.style.SUCCESS(f'Successfully reordered {users_updated_count} users. Positions now range from 1 to {current_position -1}.'))
        else:
            self.stdout.write(self.style.SUCCESS('All user positions were already sequential. No changes made.'))

        # Verify for any users with null positions if they should be handled
        # For now, this script only compacts existing positions.
        # Users with NULL positions remain NULL.

        self.stdout.write('Reordering complete.') 