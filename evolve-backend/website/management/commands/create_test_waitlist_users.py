import random
import string
from django.core.management.base import BaseCommand
from django.db import transaction, IntegrityError
from django.db.models import Max # Import Max
from website.models import WaitlistedAppUser # Ensure this import path is correct for your project structure

class Command(BaseCommand):
    help = 'Creates 32 test WaitlistedAppUser objects with phone numbers starting with 696.'

    def handle(self, *args, **options):
        created_count = 0
        phone_generation_attempts = 0
        max_phone_attempts_per_user = 10

        # Determine the starting position for new users
        # This is done once before the loop to avoid repeated Max queries in a tight loop context
        max_pos_data = WaitlistedAppUser.objects.aggregate(current_max_pos=Max('position'))
        next_position_start = (max_pos_data['current_max_pos'] if max_pos_data['current_max_pos'] is not None else 0) + 1

        self.stdout.write(self.style.SUCCESS(f"Starting to create users from position: {next_position_start}"))

        for i in range(32):
            phone_number_generated = False
            current_phone_attempts = 0
            generated_phone_number = None

            while not phone_number_generated and current_phone_attempts < max_phone_attempts_per_user:
                random_digits = ''.join(random.choices(string.digits, k=7))
                phone_number = f"696{random_digits}"
                phone_generation_attempts += 1
                current_phone_attempts += 1

                if not WaitlistedAppUser.objects.filter(phone_number=phone_number).exists():
                    generated_phone_number = phone_number
                    phone_number_generated = True
                else:
                    if current_phone_attempts == max_phone_attempts_per_user:
                        self.stdout.write(self.style.WARNING(f"Could not generate a unique phone number for user slot {i+1} after {max_phone_attempts_per_user} attempts."))
            
            if not phone_number_generated or generated_phone_number is None:
                self.stderr.write(self.style.ERROR(f"Skipping user slot {i+1} due to failure in generating a unique phone number."))
                continue # Skip to the next user slot if phone number couldn't be generated

            # Calculate the position for the current user based on the loop index and starting position
            current_user_position = next_position_start + i

            try:
                with transaction.atomic(): # Keep atomic for individual user creation integrity
                    user = WaitlistedAppUser.objects.create(
                        phone_number=generated_phone_number,
                        position=current_user_position # Explicitly set the position
                    )
                self.stdout.write(self.style.SUCCESS(f"Successfully created WaitlistedAppUser with phone {user.phone_number}, ID: {user.id}, Position: {user.position}"))
                created_count += 1
            except IntegrityError as e:
                # This should ideally not happen for position if logic is correct, but could be other integrity issues
                self.stderr.write(self.style.ERROR(f"Error creating user with phone {generated_phone_number} at position {current_user_position}: {e}"))
            except Exception as e:
                self.stderr.write(self.style.ERROR(f"An unexpected error occurred for user with phone {generated_phone_number} at position {current_user_position}: {e}"))

        self.stdout.write(self.style.SUCCESS(f"Finished creating users. Total created: {created_count}/32. Total phone generation attempts: {phone_generation_attempts}")) 