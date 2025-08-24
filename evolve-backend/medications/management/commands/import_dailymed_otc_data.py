import os
import xml.etree.ElementTree as ET
import zipfile
import requests
from django.core.management.base import BaseCommand
from django.db import transaction
from medications.models import Manufacturer, OTCMedication, DrugCategory
import re


class Command(BaseCommand):
    help = 'Download and import DailyMed OTC medication data'

    def add_arguments(self, parser):
        parser.add_argument(
            '--url',
            type=str,
            default='https://dailymed.nlm.nih.gov/dailymed/spl-resources/dm_spl_release_human_otc_part1.zip',
            help='URL to download OTC data (default: DailyMed OTC part 1)'
        )
        parser.add_argument(
            '--limit',
            type=int,
            help='Limit number of records to import (for testing)'
        )
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Clear existing OTC medication data before import'
        )

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('Starting DailyMed OTC data import...'))
        
        if options['clear']:
            self.stdout.write('Clearing existing OTC medication data...')
            OTCMedication.objects.all().delete()
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
        zip_filename = '/tmp/dailymed_otc_data.zip'
        with open(zip_filename, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        self.stdout.write('Download completed. Extracting and processing data...')
        
        # Extract and process the XML files
        try:
            with zipfile.ZipFile(zip_filename, 'r') as zip_ref:
                # Get list of XML files
                xml_files = [f for f in zip_ref.namelist() if f.endswith('.xml')]
                
                if not xml_files:
                    self.stdout.write(self.style.ERROR('No XML files found in the zip archive'))
                    return
                
                self.stdout.write(f'Found {len(xml_files)} XML files to process')
                
                # Process XML files
                self.process_xml_files(zip_ref, xml_files, options.get('limit'))
                    
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
        
        self.stdout.write(self.style.SUCCESS('DailyMed OTC data import completed successfully!'))

    def process_xml_files(self, zip_ref, xml_files, limit=None):
        """Process XML files from DailyMed and extract OTC medication data"""
        created_count = 0
        error_count = 0
        manufacturers_cache = {}
        categories_cache = {}
        
        self.stdout.write(f'Processing {len(xml_files)} XML files (limit: {limit or "unlimited"})...')
        
        with transaction.atomic():
            for file_num, xml_file in enumerate(xml_files, 1):
                if limit and file_num > limit:
                    break
                
                try:
                    with zip_ref.open(xml_file) as f:
                        xml_content = f.read().decode('utf-8', errors='ignore')
                        
                    # Parse XML
                    root = ET.fromstring(xml_content)
                    
                    # Extract medication data from XML
                    medication_data = self.extract_medication_data(root)
                    
                    if medication_data:
                        # Get or create manufacturer
                        manufacturer_name = medication_data.get('manufacturer_name', 'Unknown')
                        if manufacturer_name not in manufacturers_cache:
                            manufacturer, _ = Manufacturer.objects.get_or_create(
                                name=manufacturer_name,
                                defaults={'description': f'Manufacturer imported from DailyMed OTC data'}
                            )
                            manufacturers_cache[manufacturer_name] = manufacturer
                        
                        manufacturer = manufacturers_cache[manufacturer_name]
                        
                        # Create OTC medication
                        otc_medication = OTCMedication.objects.create(
                            product_name=medication_data.get('product_name', 'Unknown Product'),
                            brand_name=medication_data.get('brand_name', ''),
                            active_ingredients=medication_data.get('active_ingredients', []),
                            inactive_ingredients=medication_data.get('inactive_ingredients', []),
                            strength=medication_data.get('strength', ''),
                            dosage_form=medication_data.get('dosage_form', ''),
                            package_size=medication_data.get('package_size', ''),
                            manufacturer=manufacturer,
                            purpose=medication_data.get('purpose', ''),
                            uses=medication_data.get('uses', ''),
                            warnings=medication_data.get('warnings', ''),
                            directions=medication_data.get('directions', ''),
                            other_information=medication_data.get('other_information', ''),
                            drug_facts=medication_data.get('drug_facts', {}),
                            search_keywords=medication_data.get('search_keywords', []),
                            is_active=True
                        )
                        
                        # Add categories if any
                        for category_name in medication_data.get('categories', []):
                            if category_name not in categories_cache:
                                category, _ = DrugCategory.objects.get_or_create(
                                    name=category_name,
                                    defaults={'description': f'Category imported from DailyMed OTC data'}
                                )
                                categories_cache[category_name] = category
                            
                            otc_medication.categories.add(categories_cache[category_name])
                        
                        created_count += 1
                    
                    # Progress indicator
                    if file_num % 100 == 0:
                        self.stdout.write(f'Processed {file_num} files...')
                        
                except Exception as e:
                    error_count += 1
                    if error_count <= 10:  # Only show first 10 errors
                        self.stdout.write(f'Error processing file {xml_file}: {e}')
        
        self.stdout.write(
            self.style.SUCCESS(
                f'Import completed:\n'
                f'  Created: {created_count} OTC medications\n'
                f'  Errors: {error_count} files\n'
                f'  Total processed: {file_num} files'
            )
        )

    def extract_medication_data(self, root):
        """Extract medication data from DailyMed XML"""
        try:
            # Define namespaces
            namespaces = {
                'hl7': 'urn:hl7-org:v3',
                'xsi': 'http://www.w3.org/2001/XMLSchema-instance'
            }
            
            # Extract basic product information
            product_name = self.get_text_content(root, './/hl7:manufacturedProduct/hl7:manufacturedLabeledDrug/hl7:name', namespaces)
            brand_name = self.get_text_content(root, './/hl7:manufacturedProduct/hl7:manufacturedMedicine/hl7:name', namespaces)
            
            # Extract manufacturer
            manufacturer_name = self.get_text_content(root, './/hl7:representedOrganization/hl7:name', namespaces)
            
            # Extract active ingredients
            active_ingredients = []
            for ingredient in root.findall('.//hl7:activeIngredient', namespaces):
                ingredient_name = self.get_text_content(ingredient, './/hl7:name', namespaces)
                if ingredient_name:
                    active_ingredients.append(ingredient_name)
            
            # Extract inactive ingredients
            inactive_ingredients = []
            for ingredient in root.findall('.//hl7:inactiveIngredient', namespaces):
                ingredient_name = self.get_text_content(ingredient, './/hl7:name', namespaces)
                if ingredient_name:
                    inactive_ingredients.append(ingredient_name)
            
            # Extract dosage form
            dosage_form = self.get_text_content(root, './/hl7:formCode/@displayName', namespaces)
            
            # Extract text content for drug facts
            purpose = self.extract_section_content(root, 'PURPOSE', namespaces)
            uses = self.extract_section_content(root, 'INDICATIONS & USAGE', namespaces)
            warnings = self.extract_section_content(root, 'WARNINGS', namespaces)
            directions = self.extract_section_content(root, 'DOSAGE & ADMINISTRATION', namespaces)
            
            # Generate search keywords
            keywords = []
            if product_name:
                keywords.extend(product_name.split())
            if brand_name:
                keywords.extend(brand_name.split())
            keywords.extend(active_ingredients)
            
            # Clean and deduplicate keywords
            keywords = list(set([kw.strip().lower() for kw in keywords if kw.strip()]))
            
            return {
                'product_name': product_name or 'Unknown Product',
                'brand_name': brand_name or '',
                'manufacturer_name': manufacturer_name or 'Unknown Manufacturer',
                'active_ingredients': active_ingredients,
                'inactive_ingredients': inactive_ingredients,
                'dosage_form': dosage_form or '',
                'purpose': purpose,
                'uses': uses,
                'warnings': warnings,
                'directions': directions,
                'search_keywords': keywords,
                'drug_facts': {
                    'purpose': purpose,
                    'uses': uses,
                    'warnings': warnings,
                    'directions': directions,
                }
            }
            
        except Exception as e:
            self.stdout.write(f'Error extracting data from XML: {e}')
            return None

    def get_text_content(self, element, xpath, namespaces):
        """Get text content from XML element using XPath"""
        try:
            found = element.find(xpath, namespaces)
            if found is not None:
                return found.text or found.get('displayName', '')
            return ''
        except Exception:
            return ''

    def extract_section_content(self, root, section_title, namespaces):
        """Extract content from specific sections in the XML"""
        try:
            # Look for sections with specific titles
            for section in root.findall('.//hl7:section', namespaces):
                title_elem = section.find('.//hl7:title', namespaces)
                if title_elem is not None and section_title.lower() in title_elem.text.lower():
                    # Extract text content from this section
                    text_parts = []
                    for text_elem in section.findall('.//hl7:text', namespaces):
                        if text_elem.text:
                            text_parts.append(text_elem.text.strip())
                    return ' '.join(text_parts)
            return ''
        except Exception:
            return ''