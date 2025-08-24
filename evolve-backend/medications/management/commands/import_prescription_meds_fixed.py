import os
import zipfile
import xml.etree.ElementTree as ET
import shutil
from pathlib import Path
from django.core.management.base import BaseCommand
from django.db import transaction
from django.db import IntegrityError
from medications.models import Manufacturer, PrescriptionMedication, DrugCategory


class Command(BaseCommand):
    help = 'Import prescription medications with better error handling'

    def add_arguments(self, parser):
        parser.add_argument(
            '--prescription-folder',
            type=str,
            required=True,
            help='Path to folder containing prescription medication zip files'
        )
        parser.add_argument(
            '--limit',
            type=int,
            help='Limit number of files to process (for testing)'
        )
        parser.add_argument(
            '--temp-dir',
            type=str,
            default='/tmp/dailymed_extract',
            help='Temporary directory for extracting files'
        )

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('Starting prescription medication import with error handling...'))
        
        # Create temp directory
        temp_dir = Path(options['temp_dir'])
        temp_dir.mkdir(exist_ok=True)
        
        try:
            # Process prescription medications
            rx_count = self.process_prescription_folder(
                options['prescription_folder'], 
                temp_dir, 
                limit=options.get('limit')
            )
            
            self.stdout.write(
                self.style.SUCCESS(
                    f'Import completed:\n'
                    f'  Prescription medications: {rx_count}\n'
                    f'  Total prescription medications in DB: {PrescriptionMedication.objects.count()}'
                )
            )
            
        finally:
            # Clean up temp directory
            if temp_dir.exists():
                shutil.rmtree(temp_dir)
                self.stdout.write('Cleaned up temporary files.')

    def process_prescription_folder(self, folder_path, temp_dir, limit=None):
        """Process prescription medication zip files with individual transaction handling"""
        folder = Path(folder_path)
        if not folder.exists():
            self.stdout.write(f'Folder not found: {folder_path}')
            return 0
        
        zip_files = list(folder.glob('*.zip'))
        if limit:
            zip_files = zip_files[:limit]
        
        self.stdout.write(f'Processing {len(zip_files)} prescription zip files...')
        
        processed_count = 0
        error_count = 0
        manufacturers_cache = {}
        categories_cache = self.get_or_create_categories()
        
        for zip_path in zip_files:
            try:
                # Process each file in its own transaction
                with transaction.atomic():
                    medication_data = self.extract_and_parse_zip(zip_path, temp_dir)
                    if medication_data and medication_data.get('product_name') and medication_data.get('product_name') != 'Unknown':
                        
                        # Get or create manufacturer
                        manufacturer_name = medication_data.get('manufacturer', 'Unknown Manufacturer')
                        if manufacturer_name not in manufacturers_cache:
                            manufacturer, _ = Manufacturer.objects.get_or_create(
                                name=manufacturer_name[:100],
                                defaults={'description': f'Manufacturer from DailyMed data'}
                            )
                            manufacturers_cache[manufacturer_name] = manufacturer
                        
                        manufacturer = manufacturers_cache[manufacturer_name]
                        
                        # Create medication record
                        self.create_prescription_medication(medication_data, manufacturer, categories_cache)
                        processed_count += 1
                        
                        # Progress indicator
                        if processed_count % 10 == 0:
                            self.stdout.write(f'Processed {processed_count} medications...')
                    
            except IntegrityError as e:
                error_count += 1
                self.stdout.write(f'Integrity error for {zip_path.name}: {e}')
                continue
            except Exception as e:
                error_count += 1
                self.stdout.write(f'Error processing {zip_path.name}: {e}')
                continue
        
        self.stdout.write(f'Successfully processed: {processed_count}, Errors: {error_count}')
        return processed_count

    def extract_and_parse_zip(self, zip_path, temp_dir):
        """Extract zip file and parse XML with improved SPL parsing"""
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
                return None
            
            xml_file = xml_files[0]
            image_file = image_files[0] if image_files else None
            
            # Parse XML with improved SPL parser
            medication_data = self.parse_spl_xml(xml_file)
            
            # Add image information
            if image_file:
                medication_data['image_path'] = str(image_file)
                medication_data['image_filename'] = image_file.name
                medication_data['has_image'] = True
            else:
                medication_data['has_image'] = False
            
            return medication_data
            
        except Exception as e:
            self.stdout.write(f'Error extracting {zip_path.name}: {e}')
            return None

    def parse_spl_xml(self, xml_file):
        """Parse DailyMed SPL XML file with proper namespace handling"""
        try:
            tree = ET.parse(xml_file)
            root = tree.getroot()
            
            # Define namespace
            ns = {'hl7': 'urn:hl7-org:v3'}
            
            medication_data = {
                'product_name': '',
                'generic_name': '',
                'brand_name': '',
                'manufacturer': '',
                'active_ingredients': [],
                'inactive_ingredients': [],
                'strength': '',
                'dosage_form': '',
                'route': '',
                'ndc_number': '',
                'purpose': '',
                'search_keywords': []
            }
            
            # Extract manufacturer name
            manufacturer_elements = root.findall('.//hl7:author//hl7:representedOrganization/hl7:name', ns)
            if manufacturer_elements:
                medication_data['manufacturer'] = manufacturer_elements[0].text.strip()
            
            # Extract product information from manufacturedProduct section
            manufactured_product = root.find('.//hl7:subject/hl7:manufacturedProduct/hl7:manufacturedProduct', ns)
            
            if manufactured_product is not None:
                # Extract NDC number
                ndc_element = manufactured_product.find('hl7:code[@codeSystem="2.16.840.1.113883.6.69"]', ns)
                if ndc_element is not None:
                    medication_data['ndc_number'] = ndc_element.get('code', '')
                
                # Extract product name
                name_element = manufactured_product.find('hl7:name', ns)
                if name_element is not None and name_element.text:
                    medication_data['product_name'] = name_element.text.strip()
                    medication_data['brand_name'] = name_element.text.strip()
                
                # Extract generic name
                generic_element = manufactured_product.find('.//hl7:asEntityWithGeneric/hl7:genericMedicine/hl7:name', ns)
                if generic_element is not None and generic_element.text:
                    medication_data['generic_name'] = generic_element.text.strip()
                
                # Extract dosage form
                form_element = manufactured_product.find('hl7:formCode', ns)
                if form_element is not None:
                    medication_data['dosage_form'] = form_element.get('displayName', '')
                
                # Extract active ingredients
                active_ingredients = []
                active_ingredient_elements = manufactured_product.findall('.//hl7:ingredient[@classCode="ACTIB"]', ns)
                
                for ingredient in active_ingredient_elements:
                    ingredient_name_elem = ingredient.find('.//hl7:ingredientSubstance/hl7:name', ns)
                    if ingredient_name_elem is not None and ingredient_name_elem.text:
                        ingredient_name = ingredient_name_elem.text.strip()
                        
                        # Extract strength
                        quantity_elem = ingredient.find('hl7:quantity', ns)
                        strength = ''
                        if quantity_elem is not None:
                            numerator = quantity_elem.find('hl7:numerator', ns)
                            if numerator is not None:
                                value = numerator.get('value', '')
                                unit = numerator.get('unit', '')
                                if value and unit:
                                    strength = f"{value} {unit}"
                        
                        if strength:
                            active_ingredients.append(f"{ingredient_name} {strength}")
                        else:
                            active_ingredients.append(ingredient_name)
                
                medication_data['active_ingredients'] = active_ingredients
                
                # Extract route of administration
                route_element = root.find('.//hl7:consumedIn/hl7:substanceAdministration/hl7:routeCode', ns)
                if route_element is not None:
                    medication_data['route'] = route_element.get('displayName', '')
            
            # Generate search keywords
            keywords = []
            if medication_data['product_name']:
                keywords.extend(medication_data['product_name'].lower().split())
            if medication_data['generic_name']:
                keywords.extend(medication_data['generic_name'].lower().split())
            if medication_data['manufacturer']:
                keywords.extend(medication_data['manufacturer'].lower().split())
            for ingredient in medication_data['active_ingredients']:
                keywords.extend(ingredient.lower().split())
            
            # Clean keywords
            keywords = list(set([
                kw.strip() for kw in keywords 
                if kw.strip() and len(kw.strip()) > 2 and kw.strip().isalpha()
            ]))
            medication_data['search_keywords'] = keywords[:15]
            
            return medication_data
            
        except Exception as e:
            self.stdout.write(f'Error parsing XML {xml_file}: {e}')
            return None

    def create_prescription_medication(self, med_data, manufacturer, categories):
        """Create a prescription medication record with better error handling"""
        try:
            # Validate required fields
            if not med_data.get('product_name') or med_data['product_name'] == 'Unknown':
                return
            
            image_url = ''
            if med_data.get('has_image'):
                image_url = f"/media/medication_labels/{med_data.get('image_filename', 'default.jpg')}"
            
            # Generate unique NDC if missing
            ndc_number = med_data.get('ndc_number')
            if not ndc_number:
                ndc_number = f"PB-{hash(med_data['product_name']) % 10000000}"
            
            # Check if medication already exists (prevent duplicates)
            if PrescriptionMedication.objects.filter(
                brand_name=med_data['product_name'][:100],
                manufacturer=manufacturer
            ).exists():
                return  # Skip duplicate
            
            PrescriptionMedication.objects.create(
                brand_name=med_data['product_name'][:100],
                generic_name=(med_data['generic_name'][:100] if med_data['generic_name'] 
                            else med_data['product_name'][:100]),
                ndc_number=ndc_number[:20],
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
            raise Exception(f'Error creating prescription medication: {e}')

    def get_or_create_categories(self):
        """Get or create standard drug categories"""
        categories = {}
        
        category_names = [
            'Pain Relief', 'Cardiovascular', 'Diabetes', 'Blood Pressure',
            'Cholesterol', 'Antibiotics', 'Anti-inflammatory', 'Gastrointestinal',
            'Allergy', 'Cold & Flu', 'Vitamins & Supplements', 'Smoking Cessation',
            'Topical', 'Respiratory'
        ]
        
        for name in category_names:
            category, _ = DrugCategory.objects.get_or_create(
                name=name,
                defaults={'description': f'{name} medications from DailyMed import'}
            )
            categories[name.lower()] = category
        
        return categories