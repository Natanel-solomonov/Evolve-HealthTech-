import json
from django.core.management.base import BaseCommand
from django.conf import settings
from website.models import University
import os

class Command(BaseCommand):
    help = 'Populates the database with University instances from a JSON file.'

    def handle(self, *args, **options):
        # Construct the full path to the JSON file
        # Assuming universities.json is in the root of your Django project (where manage.py is)
        # If it's elsewhere, you'll need to adjust the path.
        json_file_path = os.path.join(settings.BASE_DIR, 'universities.json')

        self.stdout.write(f"Looking for universities data at: {json_file_path}")

        try:
            with open(json_file_path, 'r') as f:
                data = json.load(f)
        except FileNotFoundError:
            self.stderr.write(self.style.ERROR(f"Error: The file {json_file_path} was not found."))
            return
        except json.JSONDecodeError:
            self.stderr.write(self.style.ERROR(f"Error: Could not decode JSON from {json_file_path}."))
            return
        except Exception as e:
            self.stderr.write(self.style.ERROR(f"An unexpected error occurred while reading the file: {e}"))
            return

        universities_data = data.get('universities', [])
        
        if not universities_data:
            self.stdout.write(self.style.WARNING("No universities found in the JSON file or the 'universities' key is missing/empty."))
            return

        created_count = 0
        skipped_count = 0

        for uni_data in universities_data:
            name = uni_data.get('name')
            aliases = uni_data.get('aliases', [])

            if not name:
                self.stdout.write(self.style.WARNING("Skipping entry with no name."))
                skipped_count += 1
                continue

            # Using get_or_create to avoid duplicate entries if the command is run multiple times
            # It checks based on the 'name' field, which is unique in your model.
            university, created = University.objects.get_or_create(
                name=name,
                defaults={'aliases': aliases}
            )

            if created:
                self.stdout.write(self.style.SUCCESS(f"Successfully created University: {name}"))
                created_count += 1
            else:
                # Optionally, update aliases if the university already exists
                # university.aliases = aliases
                # university.save()
                # self.stdout.write(self.style.NOTICE(f"University {name} already exists. Aliases updated (if changed)."))
                self.stdout.write(self.style.NOTICE(f"University {name} already exists. Skipped creation."))
                skipped_count += 1
        
        self.stdout.write(self.style.SUCCESS(f"Finished populating universities. Created: {created_count}, Skipped (already existing or no name): {skipped_count}")) 