import csv
import requests
from io import StringIO
from django.core.management.base import BaseCommand
from django.db import transaction
from medications.models import Manufacturer, PrescriptionMedication


class Command(BaseCommand):
    help = 'Download and import FDA Orange Book data for prescription medications'

    def add_arguments(self, parser):
        parser.add_argument(
            '--url',
            type=str,
            default='https://data.nber.org/fda/orange-book/products.csv',
            help='URL to download Orange Book data'
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
        self.stdout.write(self.style.SUCCESS('Starting FDA Orange Book data import...'))
        
        if options['clear']:
            self.stdout.write('Clearing existing prescription medication data...')
            PrescriptionMedication.objects.all().delete()
            self.stdout.write(self.style.SUCCESS('Cleared existing data.'))
        
        # Download the CSV data
        self.stdout.write(f"Downloading data from {options['url']}...")
        try:
            response = requests.get(options['url'])
            response.raise_for_status()
        except requests.RequestException as e:
            self.stdout.write(self.style.ERROR(f'Failed to download data: {e}'))
            return

        self.stdout.write('Download completed. Processing CSV data...')
        
        # Process the CSV data
        self.process_orange_book_csv(response.text, options.get('limit'))
        
        self.stdout.write(self.style.SUCCESS('FDA Orange Book data import completed successfully!'))

    def process_orange_book_csv(self, csv_content, limit=None):
        """Process the Orange Book CSV data and import into database"""
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
                    # Extract data from Orange Book CSV row
                    # Orange Book fields: Ingredient, DF;Route, Trade_Name, Applicant, Strength, Appl_Type, Appl_No, Product_No, TE_Code, Approval_Date, RLD, Type, Applicant_Full_Name
                    
                    trade_name = row.get('Trade_Name', '').strip()
                    ingredient = row.get('Ingredient', '').strip()
                    applicant_name = row.get('Applicant_Full_Name', '').strip() or row.get('Applicant', '').strip()
                    strength = row.get('Strength', '').strip()
                    dosage_form = row.get('DF;Route', '').strip()
                    approval_date = row.get('Approval_Date', '').strip()
                    appl_no = row.get('Appl_No', '').strip()
                    
                    # Skip if no trade name or ingredient
                    if not trade_name and not ingredient:
                        continue
                    
                    # Use trade name if available, otherwise use ingredient as brand name
                    brand_name = trade_name if trade_name else ingredient
                    generic_name = ingredient if trade_name else ''
                    
                    # Get or create manufacturer
                    if applicant_name and applicant_name not in manufacturers_cache:
                        manufacturer, _ = Manufacturer.objects.get_or_create(
                            name=applicant_name,
                            defaults={'description': f'Manufacturer imported from FDA Orange Book'}
                        )
                        manufacturers_cache[applicant_name] = manufacturer
                    elif applicant_name:
                        manufacturer = manufacturers_cache[applicant_name]
                    else:
                        # Skip if no manufacturer
                        continue
                    
                    # Process active ingredients
                    ingredients_list = []
                    if ingredient:
                        # Split by semicolon or comma if multiple ingredients
                        ingredients_list = [ing.strip() for ing in ingredient.replace(';', ',').split(',') if ing.strip()]
                    
                    # Parse dosage form and route
                    route = ''
                    if ';' in dosage_form:
                        form_parts = dosage_form.split(';')
                        dosage_form = form_parts[0].strip() if form_parts else ''
                        route = form_parts[1].strip() if len(form_parts) > 1 else ''
                    
                    # Parse approval date
                    approval_date_obj = None
                    if approval_date:
                        try:
                            from datetime import datetime
                            # Try different date formats
                            for date_format in ['%b %d, %Y', '%Y-%m-%d', '%m/%d/%Y']:
                                try:
                                    approval_date_obj = datetime.strptime(approval_date, date_format).date()
                                    break
                                except ValueError:
                                    continue
                        except Exception:
                            pass
                    
                    # Create synthetic NDC number from application number
                    ndc_number = f"FDA-{appl_no}" if appl_no else f"OB-{row_num:06d}"
                    
                    # Create medication data
                    medication_data = {
                        'brand_name': brand_name,
                        'generic_name': generic_name,
                        'active_ingredients': ingredients_list,
                        'manufacturer': manufacturer,
                        'strength': strength,
                        'dosage_form': dosage_form,
                        'route_of_administration': route,
                        'fda_application_number': appl_no,
                        'approval_date': approval_date_obj,
                        'is_active': True,
                    }
                    
                    # Generate search keywords
                    keywords = []
                    if brand_name:
                        keywords.extend(brand_name.split())
                    if generic_name:
                        keywords.extend(generic_name.split())
                    keywords.extend(ingredients_list)
                    if strength:
                        keywords.extend(strength.split())
                    medication_data['search_keywords'] = list(set([kw.strip().lower() for kw in keywords if kw.strip()]))
                    
                    # Check if medication already exists by NDC or similar data
                    existing = PrescriptionMedication.objects.filter(
                        ndc_number=ndc_number
                    ).first()
                    
                    if not existing:
                        # Check for similar medications by brand name and manufacturer
                        existing = PrescriptionMedication.objects.filter(
                            brand_name__iexact=brand_name,
                            manufacturer=manufacturer
                        ).first()
                    
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
                    if row_num % 100 == 0:
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