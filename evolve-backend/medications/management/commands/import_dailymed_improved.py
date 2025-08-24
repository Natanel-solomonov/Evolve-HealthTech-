import os
import zipfile
import xml.etree.ElementTree as ET
import shutil
from pathlib import Path
from django.core.management.base import BaseCommand
from django.db import transaction
from medications.models import Manufacturer, PrescriptionMedication, OTCMedication, DrugCategory


class Command(BaseCommand):
    help = 'Import DailyMed zip files with proper XML parsing for SPL format'

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
            help='Limit number of files to process per folder (for testing)'
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
        self.stdout.write(self.style.SUCCESS('Starting improved DailyMed import...'))
        
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
                limit=options.get('limit')
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
                    if medication_data and medication_data.get('product_name') != 'Unknown':
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
                'active_ingredient_text': '',
                'directions': '',
                'warnings': '',
                'drug_facts': {},
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
                
                # Extract inactive ingredients
                inactive_ingredients = []
                inactive_ingredient_elements = manufactured_product.findall('.//hl7:ingredient[@classCode="IACT"]', ns)
                
                for ingredient in inactive_ingredient_elements:
                    ingredient_name_elem = ingredient.find('.//hl7:ingredientSubstance/hl7:name', ns)
                    if ingredient_name_elem is not None and ingredient_name_elem.text:
                        inactive_ingredients.append(ingredient_name_elem.text.strip())
                
                medication_data['inactive_ingredients'] = inactive_ingredients
                
                # Extract route of administration
                route_element = root.find('.//hl7:consumedIn/hl7:substanceAdministration/hl7:routeCode', ns)
                if route_element is not None:
                    medication_data['route'] = route_element.get('displayName', '')
            
            # Extract text sections for additional information
            sections = root.findall('.//hl7:component/hl7:section', ns)
            
            for section in sections:
                code_element = section.find('hl7:code', ns)
                if code_element is not None:
                    section_code = code_element.get('code')
                    title_element = section.find('hl7:title', ns)
                    text_element = section.find('hl7:text', ns)
                    
                    if text_element is not None:
                        section_text = self.extract_text_from_element(text_element)
                        
                        # Map sections to our fields
                        if section_code == '55106-9':  # Active Ingredient Section
                            medication_data['active_ingredient_text'] = section_text
                            # Extract strength from text if not found elsewhere
                            if not medication_data['strength']:
                                import re
                                strength_match = re.search(r'(\d+\.?\d*\s*(?:mg|mcg|g|ml|%|iu|units?))', section_text.lower())
                                if strength_match:
                                    medication_data['strength'] = strength_match.group(1)
                        
                        elif section_code == '55105-1':  # Purpose Section
                            medication_data['purpose'] = section_text
                        
                        elif section_code == '34068-7':  # Dosage & Administration
                            medication_data['directions'] = section_text
                        
                        elif section_code in ['34071-1', '50570-1', '50567-7', '50566-9']:  # Warnings sections
                            if medication_data['warnings']:
                                medication_data['warnings'] += f"\n\n{section_text}"
                            else:
                                medication_data['warnings'] = section_text
            
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
            return {
                'product_name': 'Unknown',
                'manufacturer': 'Unknown Manufacturer',
                'active_ingredients': [],
                'search_keywords': []
            }

    def extract_text_from_element(self, element):
        """Extract all text content from an XML element, including nested elements"""
        text_parts = []
        
        if element.text:
            text_parts.append(element.text.strip())
        
        for child in element:
            child_text = self.extract_text_from_element(child)
            if child_text:
                text_parts.append(child_text)
            
            if child.tail:
                text_parts.append(child.tail.strip())
        
        return ' '.join(text_parts).strip()

    def create_prescription_medication(self, med_data, manufacturer, categories):
        """Create a prescription medication record"""
        try:
            image_url = ''
            if med_data.get('has_image'):
                image_url = f"/media/medication_labels/{med_data.get('image_filename', 'default.jpg')}"
            
            PrescriptionMedication.objects.create(
                brand_name=med_data['product_name'][:100],
                generic_name=(med_data['generic_name'][:100] if med_data['generic_name'] 
                            else med_data['product_name'][:100]),
                ndc_number=med_data['ndc_number'][:20] if med_data['ndc_number'] else f"DM-{manufacturer.name[:10]}",
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