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
    help = 'Process DailyMed zip files containing XML and JPG medication data'

    def add_arguments(self, parser):
        parser.add_argument(
            '--otc-folder',
            type=str,
            required=True,
            help='Path to folder containing OTC medication zip files'
        )
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
            # Process OTC medications
            otc_count = self.process_medication_folder(
                options['otc_folder'], 
                temp_dir, 
                is_prescription=False,
                limit=options.get('limit')
            )
            
            # Process prescription medications
            rx_count = self.process_medication_folder(
                options['prescription_folder'], 
                temp_dir, 
                is_prescription=True,
                limit=options.get('limit') - otc_count if options.get('limit') else None
            )
            
            self.stdout.write(
                self.style.SUCCESS(
                    f'Import completed:\n'
                    f'  OTC medications: {otc_count}\n'
                    f'  Prescription medications: {rx_count}\n'
                    f'  Total: {otc_count + rx_count}'
                )
            )
            
        finally:
            # Clean up temp directory
            if temp_dir.exists():
                shutil.rmtree(temp_dir)
                self.stdout.write('Cleaned up temporary files.')

    def process_medication_folder(self, folder_path, temp_dir, is_prescription, limit=None):
        """Process all zip files in a medication folder"""
        folder = Path(folder_path)
        if not folder.exists():
            self.stdout.write(f'Folder not found: {folder_path}')
            return 0
        
        zip_files = list(folder.glob('*.zip'))
        if limit:
            zip_files = zip_files[:limit]
        
        self.stdout.write(f'Processing {len(zip_files)} {"prescription" if is_prescription else "OTC"} zip files...')
        
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

    def extract_and_parse_zip(self, zip_path, temp_dir):
        """Extract zip file and parse XML and image"""
        try:
            # Create extraction directory
            extract_dir = temp_dir / zip_path.stem
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
                # Copy image to media directory (or store path for later processing)
                medication_data['image_path'] = str(image_file)
                medication_data['image_filename'] = image_file.name
            
            return medication_data
            
        except Exception as e:
            self.stdout.write(f'Error extracting {zip_path.name}: {e}')
            return None

    def parse_xml_file(self, xml_file):
        """Parse DailyMed XML file to extract medication information"""
        try:
            tree = ET.parse(xml_file)
            root = tree.getroot()
            
            # DailyMed XML structure varies, but common elements include:
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
            
            # Extract product name (try multiple possible paths)
            product_name = self.extract_text_from_xml(root, [
                './/manufacturedProduct//name',
                './/asManufacturedProduct//manufacturedProduct//name',
                './/title'
            ])
            medication_data['product_name'] = product_name
            medication_data['brand_name'] = product_name
            
            # Extract manufacturer
            manufacturer = self.extract_text_from_xml(root, [
                './/manufacturedProduct//manufacturerOrganization//name',
                './/representedOrganization//name',
                './/assignedEntity//representedOrganization//name'
            ])
            medication_data['manufacturer'] = manufacturer
            
            # Extract active ingredients
            ingredients = []
            ingredient_elements = root.findall('.//ingredient//ingredientSubstance//name') or \
                                root.findall('.//activeIngredient//name') or \
                                root.findall('.//substance//name')
            
            for ingredient in ingredient_elements:
                if ingredient.text:
                    ingredients.append(ingredient.text.strip())
            
            medication_data['active_ingredients'] = ingredients[:5]  # Limit to 5 ingredients
            
            # Extract strength
            strength = self.extract_text_from_xml(root, [
                './/numerator//value',
                './/strength//numerator//value',
                './/quantity//value'
            ])
            medication_data['strength'] = strength
            
            # Extract dosage form
            dosage_form = self.extract_text_from_xml(root, [
                './/formCode',
                './/administrableDoseForm//name',
                './/doseForm'
            ])
            medication_data['dosage_form'] = dosage_form
            
            # Extract NDC number
            ndc = self.extract_text_from_xml(root, [
                './/code[@codeSystem="2.16.840.1.113883.6.69"]',
                './/asContent//containerPackagedProduct//code'
            ])
            medication_data['ndc_number'] = ndc or f"DM-{xml_file.stem}"
            
            # Extract route of administration
            route = self.extract_text_from_xml(root, [
                './/routeCode',
                './/administrationUnitCode'
            ])
            medication_data['route'] = route
            
            # Extract purpose/indication
            purpose = self.extract_text_from_xml(root, [
                './/indication//text',
                './/purpose//text'
            ])
            medication_data['purpose'] = purpose
            
            # Generate search keywords
            keywords = []
            if product_name:
                keywords.extend(product_name.lower().split())
            if manufacturer:
                keywords.extend(manufacturer.lower().split())
            for ingredient in ingredients:
                keywords.extend(ingredient.lower().split())
            
            # Clean and deduplicate keywords
            keywords = list(set([kw.strip() for kw in keywords if kw.strip() and len(kw.strip()) > 2]))
            medication_data['search_keywords'] = keywords[:10]  # Limit to 10 keywords
            
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
                    # Check for code attribute if no text
                    if element.get('code'):
                        return element.get('code')
                    # Check for displayName attribute
                    if element.get('displayName'):
                        return element.get('displayName')
            except:
                continue
        return ''

    def create_prescription_medication(self, med_data, manufacturer, categories):
        """Create a prescription medication record"""
        try:
            # Handle image
            image_url = ''
            if med_data.get('image_path'):
                # For now, just store the filename - in production you'd upload to S3/media
                image_url = f"/media/medication_labels/{med_data['image_filename']}"
            
            PrescriptionMedication.objects.create(
                brand_name=med_data['product_name'][:100] if med_data['product_name'] else 'Unknown',
                generic_name=med_data['active_ingredients'][0][:100] if med_data['active_ingredients'] else med_data['product_name'][:100],
                ndc_number=med_data['ndc_number'][:20],
                active_ingredients=med_data['active_ingredients'],
                strength=med_data['strength'][:50],
                dosage_form=med_data['dosage_form'][:50],
                route_of_administration=med_data['route'][:50],
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
            # Handle image
            image_url = ''
            if med_data.get('image_path'):
                # For now, just store the filename - in production you'd upload to S3/media
                image_url = f"/media/medication_labels/{med_data['image_filename']}"
            
            OTCMedication.objects.create(
                product_name=med_data['product_name'][:100] if med_data['product_name'] else 'Unknown',
                brand_name=med_data['brand_name'][:100] if med_data['brand_name'] else med_data['product_name'][:100],
                active_ingredients=med_data['active_ingredients'],
                strength=med_data['strength'][:50],
                dosage_form=med_data['dosage_form'][:50],
                manufacturer=manufacturer,
                package_image_url=image_url,
                purpose=med_data['purpose'][:200] if med_data['purpose'] else '',
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