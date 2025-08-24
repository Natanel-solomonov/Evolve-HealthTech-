import os
import zipfile
import xml.etree.ElementTree as ET
import shutil
from pathlib import Path
from django.core.management.base import BaseCommand
from django.db import transaction
from django.core.files.base import ContentFile
from medications.models import Manufacturer, PrescriptionMedication, OTCMedication, DrugCategory


class Command(BaseCommand):
    help = 'Process DailyMed zip files from a single folder containing both OTC and prescription medications'

    def add_arguments(self, parser):
        parser.add_argument(
            '--folder',
            type=str,
            required=True,
            help='Path to folder containing all medication zip files'
        )
        parser.add_argument(
            '--limit',
            type=int,
            help='Limit number of files to process (for testing)'
        )
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Clear existing medication data before import'
        )
        parser.add_argument(
            '--temp-dir',
            type=str,
            default='/tmp/dailymed_extract',
            help='Temporary directory for extracting files'
        )

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('Starting DailyMed zip file import...'))
        
        if options['clear']:
            self.stdout.write('Clearing existing medication data...')
            PrescriptionMedication.objects.all().delete()
            OTCMedication.objects.all().delete()
            self.stdout.write(self.style.SUCCESS('Cleared existing data.'))
        
        # Create temp directory
        temp_dir = Path(options['temp_dir'])
        temp_dir.mkdir(exist_ok=True)
        
        try:
            # Process all medications
            total_count = self.process_medication_folder(
                options['folder'], 
                temp_dir, 
                limit=options.get('limit')
            )
            
            self.stdout.write(
                self.style.SUCCESS(
                    f'Import completed:\n'
                    f'  OTC medications: {OTCMedication.objects.count()}\n'
                    f'  Prescription medications: {PrescriptionMedication.objects.count()}\n'
                    f'  Total processed: {total_count}'
                )
            )
            
        finally:
            # Clean up temp directory
            if temp_dir.exists():
                shutil.rmtree(temp_dir)
                self.stdout.write('Cleaned up temporary files.')

    def process_medication_folder(self, folder_path, temp_dir, limit=None):
        """Process all zip files in the medication folder"""
        folder = Path(folder_path)
        if not folder.exists():
            self.stdout.write(f'Folder not found: {folder_path}')
            return 0
        
        zip_files = list(folder.glob('*.zip'))
        if limit:
            zip_files = zip_files[:limit]
        
        self.stdout.write(f'Processing {len(zip_files)} zip files...')
        
        processed_count = 0
        manufacturers_cache = {}
        categories_cache = self.get_or_create_categories()
        
        with transaction.atomic():
            for zip_path in zip_files:
                try:
                    medication_data = self.extract_and_parse_zip(zip_path, temp_dir)
                    if medication_data:
                        # Get or create manufacturer
                        manufacturer_name = medication_data.get('manufacturer', 'Unknown Manufacturer')
                        if manufacturer_name not in manufacturers_cache:
                            manufacturer, _ = Manufacturer.objects.get_or_create(
                                name=manufacturer_name[:100],  # Truncate if too long
                                defaults={'description': f'Manufacturer from DailyMed data'}
                            )
                            manufacturers_cache[manufacturer_name] = manufacturer
                        
                        manufacturer = manufacturers_cache[manufacturer_name]
                        
                        # Determine if prescription or OTC based on content
                        is_prescription = self.determine_if_prescription(medication_data)
                        
                        # Create medication record
                        if is_prescription:
                            self.create_prescription_medication(medication_data, manufacturer, categories_cache)
                        else:
                            self.create_otc_medication(medication_data, manufacturer, categories_cache)
                        
                        processed_count += 1
                        
                        # Progress indicator
                        if processed_count % 10 == 0:
                            self.stdout.write(f'Processed {processed_count} medications...')
                            
                except Exception as e:
                    self.stdout.write(f'Error processing {zip_path.name}: {e}')
                    continue
        
        return processed_count

    def determine_if_prescription(self, medication_data):
        """Determine if medication is prescription based on content analysis"""
        # Check for prescription indicators
        prescription_keywords = [
            'rx only', 'prescription', 'controlled substance', 'schedule',
            'ndc', 'physician', 'doctor', 'prescribe', 'prescription drug'
        ]
        
        # Check for OTC indicators
        otc_keywords = [
            'over the counter', 'otc', 'drug facts', 'dietary supplement',
            'supplement facts', 'natural', 'herbal', 'vitamin'
        ]
        
        # Combine all text fields for analysis
        text_to_analyze = ' '.join([
            medication_data.get('product_name', '').lower(),
            medication_data.get('purpose', '').lower(),
            medication_data.get('dosage_form', '').lower(),
            ' '.join(medication_data.get('active_ingredients', [])).lower()
        ])
        
        prescription_score = sum(1 for keyword in prescription_keywords if keyword in text_to_analyze)
        otc_score = sum(1 for keyword in otc_keywords if keyword in text_to_analyze)
        
        # Default to prescription if unclear
        return prescription_score >= otc_score

    def extract_and_parse_zip(self, zip_path, temp_dir):
        """Extract zip file and parse XML and image"""
        try:
            # Create extraction directory
            extract_dir = temp_dir / zip_path.stem
            if extract_dir.exists():
                shutil.rmtree(extract_dir)
            extract_dir.mkdir(exist_ok=True)
            
            # Extract zip file
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(extract_dir)
            
            # Find XML and image files
            xml_files = list(extract_dir.glob('*.xml'))
            image_files = list(extract_dir.glob('*.jpg')) + list(extract_dir.glob('*.jpeg')) + list(extract_dir.glob('*.png'))
            
            if not xml_files:
                self.stdout.write(f'No XML file found in {zip_path.name}')
                return None
            
            xml_file = xml_files[0]
            image_file = image_files[0] if image_files else None
            
            # Parse XML
            medication_data = self.parse_xml_file(xml_file)
            
            # Add image information
            if image_file:
                # For demo purposes, we'll just store the reference
                # In production, you'd upload these images to your media storage
                medication_data['image_path'] = str(image_file)
                medication_data['image_filename'] = image_file.name
                medication_data['has_image'] = True
            else:
                medication_data['has_image'] = False
            
            return medication_data
            
        except Exception as e:
            self.stdout.write(f'Error extracting {zip_path.name}: {e}')
            return None

    def parse_xml_file(self, xml_file):
        """Parse DailyMed XML file to extract medication information"""
        try:
            tree = ET.parse(xml_file)
            root = tree.getroot()
            
            # DailyMed XML structure - handle namespaces
            namespaces = {
                'ns': 'urn:hl7-org:v3',  # Common namespace for DailyMed
                '': 'urn:hl7-org:v3'
            }
            
            medication_data = {
                'product_name': '',
                'generic_name': '',
                'brand_name': '',
                'manufacturer': '',
                'active_ingredients': [],
                'strength': '',
                'dosage_form': '',
                'route': '',
                'ndc_number': '',
                'purpose': '',
                'drug_facts': {},
                'search_keywords': []
            }
            
            # Extract product name with namespace handling
            product_name = self.extract_text_from_xml(root, [
                './/name',
                './/{urn:hl7-org:v3}name',
                './/title',
                './/{urn:hl7-org:v3}title'
            ])
            
            # If still no name found, try without namespaces
            if not product_name:
                # Remove namespace prefixes for broad search
                for elem in root.iter():
                    if elem.tag.endswith('name') or elem.tag.endswith('title'):
                        if elem.text and elem.text.strip():
                            product_name = elem.text.strip()
                            break
            
            medication_data['product_name'] = product_name or f'Unknown-{xml_file.stem}'
            medication_data['brand_name'] = product_name or f'Unknown-{xml_file.stem}'
            
            # Extract manufacturer
            manufacturer = self.extract_text_from_xml(root, [
                './/manufacturerOrganization/name',
                './/representedOrganization/name',
                './/{urn:hl7-org:v3}representedOrganization//{urn:hl7-org:v3}name'
            ])
            medication_data['manufacturer'] = manufacturer or 'Unknown Manufacturer'
            
            # Extract active ingredients
            ingredients = []
            # Try multiple patterns for ingredients
            for elem in root.iter():
                if ('ingredient' in elem.tag.lower() or 'substance' in elem.tag.lower()) and elem.text:
                    ingredients.append(elem.text.strip())
                elif elem.tag.endswith('name') and elem.text:
                    # Check if this looks like an ingredient
                    text = elem.text.strip()
                    if len(text) > 3 and len(text) < 50 and any(c.isupper() for c in text):
                        ingredients.append(text)
            
            # Deduplicate and limit ingredients
            seen = set()
            unique_ingredients = []
            for ingredient in ingredients:
                if ingredient.lower() not in seen and len(unique_ingredients) < 5:
                    seen.add(ingredient.lower())
                    unique_ingredients.append(ingredient)
            
            medication_data['active_ingredients'] = unique_ingredients
            
            # Extract other fields with simpler approach
            all_text = ET.tostring(root, encoding='unicode', method='text').lower()
            
            # Look for strength patterns
            import re
            strength_patterns = [
                r'(\d+\s*mg)', r'(\d+\s*mcg)', r'(\d+\s*g)', r'(\d+\s*ml)',
                r'(\d+\s*%)', r'(\d+\s*units?)', r'(\d+\s*iu)'
            ]
            
            for pattern in strength_patterns:
                match = re.search(pattern, all_text)
                if match:
                    medication_data['strength'] = match.group(1).upper()
                    break
            
            # Extract dosage form
            dosage_forms = ['tablet', 'capsule', 'liquid', 'cream', 'ointment', 'injection', 'solution', 'suspension']
            for form in dosage_forms:
                if form in all_text:
                    medication_data['dosage_form'] = form.title()
                    break
            
            # Generate NDC number from filename if not found
            medication_data['ndc_number'] = f"DM-{xml_file.stem[:15]}"
            
            # Generate search keywords
            keywords = []
            if product_name:
                keywords.extend(product_name.lower().split())
            if manufacturer:
                keywords.extend(manufacturer.lower().split())
            for ingredient in unique_ingredients:
                keywords.extend(ingredient.lower().split())
            
            # Clean and deduplicate keywords
            keywords = list(set([
                kw.strip() for kw in keywords 
                if kw.strip() and len(kw.strip()) > 2 and kw.strip().isalpha()
            ]))
            medication_data['search_keywords'] = keywords[:10]
            
            return medication_data
            
        except Exception as e:
            self.stdout.write(f'Error parsing XML {xml_file}: {e}')
            return None

    def extract_text_from_xml(self, root, xpath_list):
        """Try multiple XPath expressions to find text content"""
        for xpath in xpath_list:
            try:
                elements = root.findall(xpath)
                for element in elements:
                    if element.text and element.text.strip():
                        return element.text.strip()
                    # Check for attributes
                    for attr in ['code', 'displayName', 'value']:
                        if element.get(attr):
                            return element.get(attr)
            except:
                continue
        return ''

    def create_prescription_medication(self, med_data, manufacturer, categories):
        """Create a prescription medication record"""
        try:
            # Generate a simple image URL reference
            image_url = ''
            if med_data.get('has_image'):
                image_url = f"/media/medication_labels/{med_data.get('image_filename', 'default.jpg')}"
            
            PrescriptionMedication.objects.create(
                brand_name=med_data['product_name'][:100],
                generic_name=(med_data['active_ingredients'][0][:100] if med_data['active_ingredients'] 
                            else med_data['product_name'][:100]),
                ndc_number=med_data['ndc_number'][:20],
                active_ingredients=med_data['active_ingredients'],
                strength=med_data['strength'][:50] if med_data['strength'] else '',
                dosage_form=med_data['dosage_form'][:50] if med_data['dosage_form'] else '',
                route_of_administration=med_data['route'][:50] if med_data['route'] else 'Oral',
                manufacturer=manufacturer,
                pill_image_url=image_url,
                search_keywords=med_data['search_keywords'],
                is_active=True
            )
        except Exception as e:
            self.stdout.write(f'Error creating prescription medication: {e}')

    def create_otc_medication(self, med_data, manufacturer, categories):
        """Create an OTC medication record"""
        try:
            # Generate a simple image URL reference
            image_url = ''
            if med_data.get('has_image'):
                image_url = f"/media/medication_labels/{med_data.get('image_filename', 'default.jpg')}"
            
            OTCMedication.objects.create(
                product_name=med_data['product_name'][:100],
                brand_name=med_data['brand_name'][:100],
                active_ingredients=med_data['active_ingredients'],
                strength=med_data['strength'][:50] if med_data['strength'] else '',
                dosage_form=med_data['dosage_form'][:50] if med_data['dosage_form'] else '',
                manufacturer=manufacturer,
                package_image_url=image_url,
                purpose=med_data['purpose'][:200] if med_data['purpose'] else 'General medication',
                search_keywords=med_data['search_keywords'],
                is_active=True
            )
        except Exception as e:
            self.stdout.write(f'Error creating OTC medication: {e}')

    def get_or_create_categories(self):
        """Get or create standard drug categories"""
        categories = {}
        
        category_names = [
            'Pain Relief', 'Cardiovascular', 'Diabetes', 'Blood Pressure',
            'Cholesterol', 'Antibiotics', 'Anti-inflammatory', 'Gastrointestinal',
            'Allergy', 'Cold & Flu', 'Vitamins & Supplements'
        ]
        
        for name in category_names:
            category, _ = DrugCategory.objects.get_or_create(
                name=name,
                defaults={'description': f'{name} medications from DailyMed import'}
            )
            categories[name.lower()] = category
        
        return categories