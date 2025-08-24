import os
import csv
import zipfile
import requests
from io import StringIO
from django.core.management.base import BaseCommand
from django.db import transaction
from medications.models import Manufacturer, PrescriptionMedication


class Command(BaseCommand):
    help = 'Download and import FDA National Drug Code (NDC) data for prescription medications'

    def add_arguments(self, parser):
        parser.add_argument(
            '--url',
            type=str,
            default='https://www.fda.gov/media/72662/download',
            help='URL to download NDC data (default: FDA NDC database)'
        )
        parser.add_argument(
            '--limit',
            type=int,
            help='Limit number of records to import (for testing)'
        )
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Clear existing prescription medication data before import'
        )

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('Starting FDA NDC data import...'))
        
        if options['clear']:
            self.stdout.write('Clearing existing prescription medication data...')
            PrescriptionMedication.objects.all().delete()
            self.stdout.write(self.style.SUCCESS('Cleared existing data.'))
        
        # Download the data
        self.stdout.write(f"Downloading data from {options['url']}...")
        try:
            response = requests.get(options['url'], stream=True)
            response.raise_for_status()
        except requests.RequestException as e:
            self.stdout.write(self.style.ERROR(f'Failed to download data: {e}'))
            return

        # Save the zip file temporarily
        zip_filename = '/tmp/ndc_data.zip'
        with open(zip_filename, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        self.stdout.write('Download completed. Extracting and processing data...')
        
        # Extract and process the CSV files
        try:
            with zipfile.ZipFile(zip_filename, 'r') as zip_ref:
                # Look for CSV files in the zip
                csv_files = [f for f in zip_ref.namelist() if f.endswith('.csv')]
                
                if not csv_files:
                    self.stdout.write(self.style.ERROR('No CSV files found in the zip archive'))
                    return
                
                # Process the main product file (usually the largest CSV)
                main_csv = max(csv_files, key=lambda f: zip_ref.getinfo(f).file_size)
                self.stdout.write(f'Processing main CSV file: {main_csv}')
                
                with zip_ref.open(main_csv) as csv_file:
                    # Read the CSV content
                    csv_content = csv_file.read().decode('utf-8')
                    self.process_ndc_csv(csv_content, options.get('limit'))
                    
        except zipfile.BadZipFile:
            self.stdout.write(self.style.ERROR('Invalid zip file downloaded'))
            return
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Error processing zip file: {e}'))
            return
        finally:
            # Clean up temporary file
            if os.path.exists(zip_filename):
                os.remove(zip_filename)
        
        self.stdout.write(self.style.SUCCESS('FDA NDC data import completed successfully!'))

    def process_ndc_csv(self, csv_content, limit=None):
        """Process the NDC CSV data and import into database"""
        csv_reader = csv.DictReader(StringIO(csv_content))
        
        created_count = 0
        updated_count = 0
        error_count = 0
        manufacturers_cache = {}
        
        self.stdout.write(f'Processing CSV data (limit: {limit or "unlimited"})...')
        
        with transaction.atomic():
            for row_num, row in enumerate(csv_reader, 1):
                if limit and row_num > limit:
                    break
                
                try:
                    # Extract data from CSV row
                    ndc_number = row.get('NDC') or row.get('ndc_number') or row.get('PRODUCTID')
                    brand_name = row.get('PROPRIETARYNAME') or row.get('brand_name') or ''
                    generic_name = row.get('NONPROPRIETARYNAME') or row.get('generic_name') or ''
                    manufacturer_name = row.get('LABELER') or row.get('manufacturer') or row.get('LABELERNAME') or ''
                    dosage_form = row.get('DOSAGEFORMNAME') or row.get('dosage_form') or ''
                    route = row.get('ROUTENAME') or row.get('route') or ''
                    active_ingredients = row.get('ACTIVE_INGREDIENT') or row.get('active_ingredients') or ''
                    strength = row.get('STRENGTH') or row.get('strength') or ''
                    
                    # Skip if no NDC number
                    if not ndc_number:
                        continue
                    
                    # Clean and format NDC number
                    ndc_number = self.format_ndc_number(ndc_number)
                    
                    # Get or create manufacturer
                    if manufacturer_name and manufacturer_name not in manufacturers_cache:
                        manufacturer, _ = Manufacturer.objects.get_or_create(
                            name=manufacturer_name.strip(),
                            defaults={'description': f'Manufacturer imported from FDA NDC data'}
                        )
                        manufacturers_cache[manufacturer_name] = manufacturer
                    elif manufacturer_name:
                        manufacturer = manufacturers_cache[manufacturer_name]
                    else:
                        # Skip if no manufacturer
                        continue
                    
                    # Process active ingredients
                    ingredients_list = []
                    if active_ingredients:
                        ingredients_list = [ing.strip() for ing in active_ingredients.split(';') if ing.strip()]
                    
                    # Create or update prescription medication
                    medication_data = {
                        'brand_name': brand_name.strip() if brand_name else 'Unknown',
                        'generic_name': generic_name.strip() if generic_name else '',
                        'active_ingredients': ingredients_list,
                        'manufacturer': manufacturer,
                        'strength': strength.strip() if strength else '',
                        'dosage_form': dosage_form.strip() if dosage_form else '',
                        'route_of_administration': route.strip() if route else '',
                        'is_active': True,
                    }
                    
                    # Generate search keywords
                    keywords = []
                    if brand_name:
                        keywords.extend(brand_name.split())
                    if generic_name:
                        keywords.extend(generic_name.split())
                    keywords.extend(ingredients_list)
                    medication_data['search_keywords'] = list(set(keywords))
                    
                    # Check if medication already exists
                    existing = PrescriptionMedication.objects.filter(ndc_number=ndc_number).first()
                    
                    if existing:
                        # Update existing medication
                        for key, value in medication_data.items():
                            setattr(existing, key, value)
                        existing.save()
                        updated_count += 1
                    else:
                        # Create new medication
                        medication_data['ndc_number'] = ndc_number
                        PrescriptionMedication.objects.create(**medication_data)
                        created_count += 1
                    
                    # Progress indicator
                    if row_num % 1000 == 0:
                        self.stdout.write(f'Processed {row_num} rows...')
                        
                except Exception as e:
                    error_count += 1
                    if error_count <= 10:  # Only show first 10 errors
                        self.stdout.write(f'Error processing row {row_num}: {e}')
        
        self.stdout.write(
            self.style.SUCCESS(
                f'Import completed:\n'
                f'  Created: {created_count} medications\n'
                f'  Updated: {updated_count} medications\n'
                f'  Errors: {error_count} rows\n'
                f'  Total processed: {row_num} rows'
            )
        )

    def format_ndc_number(self, ndc):
        """Format NDC number to standard format"""
        # Remove any non-numeric characters except hyphens
        ndc = ''.join(c for c in ndc if c.isdigit() or c == '-')
        
        # If no hyphens, add them in standard format (XXXXX-XXX-XX)
        if '-' not in ndc and len(ndc) >= 10:
            ndc = f"{ndc[:5]}-{ndc[5:8]}-{ndc[8:]}"
        
        return ndc