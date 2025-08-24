from django.core.management.base import BaseCommand
from django.db import transaction
from medications.models import (
    Manufacturer, DrugCategory, PrescriptionMedication, 
    OTCMedication, Supplement
)


class Command(BaseCommand):
    help = 'Create sample medication data for testing'

    def add_arguments(self, parser):
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Clear existing medication data before creating samples'
        )

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('Creating sample medication data...'))
        
        if options['clear']:
            self.stdout.write('Clearing existing data...')
            PrescriptionMedication.objects.all().delete()
            OTCMedication.objects.all().delete()
            Supplement.objects.all().delete()
            DrugCategory.objects.all().delete()
            Manufacturer.objects.all().delete()
            self.stdout.write(self.style.SUCCESS('Cleared existing data.'))
        
        with transaction.atomic():
            # Create manufacturers
            manufacturers = {
                'pfizer': Manufacturer.objects.create(
                    name='Pfizer Inc.',
                    description='Global pharmaceutical company',
                    website='https://www.pfizer.com'
                ),
                'johnson': Manufacturer.objects.create(
                    name='Johnson & Johnson',
                    description='Healthcare and pharmaceutical company',
                    website='https://www.jnj.com'
                ),
                'bayer': Manufacturer.objects.create(
                    name='Bayer HealthCare',
                    description='Healthcare and pharmaceutical division of Bayer',
                    website='https://www.bayer.com'
                ),
                'generic': Manufacturer.objects.create(
                    name='Generic Pharmaceuticals',
                    description='Generic drug manufacturer'
                ),
                'nature_made': Manufacturer.objects.create(
                    name='Nature Made',
                    description='Vitamin and supplement manufacturer',
                    website='https://www.naturemade.com'
                ),
            }
            
            # Create drug categories
            categories = {
                'pain_relief': DrugCategory.objects.create(
                    name='Pain Relief',
                    description='Medications for pain management'
                ),
                'cardiovascular': DrugCategory.objects.create(
                    name='Cardiovascular',
                    description='Heart and blood vessel medications'
                ),
                'digestive': DrugCategory.objects.create(
                    name='Digestive Health',
                    description='Stomach and digestive system medications'
                ),
                'cold_flu': DrugCategory.objects.create(
                    name='Cold & Flu',
                    description='Cold and flu relief medications'
                ),
                'vitamins': DrugCategory.objects.create(
                    name='Vitamins & Minerals',
                    description='Essential vitamins and minerals'
                ),
                'immune': DrugCategory.objects.create(
                    name='Immune Support',
                    description='Immune system support supplements'
                ),
            }
            
            # Create sample prescription medications
            prescription_meds = [
                {
                    'brand_name': 'Lipitor',
                    'generic_name': 'Atorvastatin',
                    'ndc_number': '00071-0155-23',
                    'active_ingredients': ['Atorvastatin calcium'],
                    'strength': '20 mg',
                    'dosage_form': 'Tablet',
                    'route_of_administration': 'Oral',
                    'manufacturer': manufacturers['pfizer'],
                    'categories': [categories['cardiovascular']],
                    'indications': 'Treatment of high cholesterol and prevention of cardiovascular disease',
                    'warnings_precautions': 'May cause muscle pain. Monitor liver function.',
                    'dosage_instructions': 'Take once daily with or without food',
                    'search_keywords': ['lipitor', 'atorvastatin', 'cholesterol', 'statin']
                },
                {
                    'brand_name': 'Zoloft',
                    'generic_name': 'Sertraline',
                    'ndc_number': '00071-0157-24',
                    'active_ingredients': ['Sertraline hydrochloride'],
                    'strength': '50 mg',
                    'dosage_form': 'Tablet',
                    'route_of_administration': 'Oral',
                    'manufacturer': manufacturers['pfizer'],
                    'categories': [],
                    'indications': 'Treatment of depression and anxiety disorders',
                    'warnings_precautions': 'May increase suicidal thoughts in young adults',
                    'dosage_instructions': 'Take once daily, preferably in the morning',
                    'search_keywords': ['zoloft', 'sertraline', 'depression', 'anxiety', 'ssri']
                },
                {
                    'brand_name': 'Metformin',
                    'generic_name': 'Metformin hydrochloride',
                    'ndc_number': '00093-7214-01',
                    'active_ingredients': ['Metformin hydrochloride'],
                    'strength': '500 mg',
                    'dosage_form': 'Tablet',
                    'route_of_administration': 'Oral',
                    'manufacturer': manufacturers['generic'],
                    'categories': [],
                    'indications': 'Treatment of type 2 diabetes',
                    'warnings_precautions': 'May cause lactic acidosis. Monitor kidney function.',
                    'dosage_instructions': 'Take with meals to reduce stomach upset',
                    'search_keywords': ['metformin', 'diabetes', 'blood sugar', 'glucose']
                },
            ]
            
            for med_data in prescription_meds:
                categories_list = med_data.pop('categories', [])
                med = PrescriptionMedication.objects.create(**med_data)
                med.categories.set(categories_list)
            
            # Create sample OTC medications
            otc_meds = [
                {
                    'product_name': 'Tylenol Extra Strength',
                    'brand_name': 'Tylenol',
                    'active_ingredients': ['Acetaminophen'],
                    'strength': '500 mg',
                    'dosage_form': 'Caplet',
                    'package_size': '100 caplets',
                    'manufacturer': manufacturers['johnson'],
                    'categories': [categories['pain_relief']],
                    'purpose': 'Pain reliever/fever reducer',
                    'uses': 'Temporarily relieves minor aches and pains, reduces fever',
                    'warnings': 'Do not exceed 8 caplets in 24 hours. Liver warning: contains acetaminophen.',
                    'directions': 'Adults: take 2 caplets every 6 hours while symptoms persist',
                    'upc_code': '300450271044',
                    'search_keywords': ['tylenol', 'acetaminophen', 'pain', 'fever', 'headache']
                },
                {
                    'product_name': 'Advil Liqui-Gels',
                    'brand_name': 'Advil',
                    'active_ingredients': ['Ibuprofen'],
                    'strength': '200 mg',
                    'dosage_form': 'Liquid-filled capsule',
                    'package_size': '80 capsules',
                    'manufacturer': manufacturers['pfizer'],
                    'categories': [categories['pain_relief']],
                    'purpose': 'Pain reliever/fever reducer',
                    'uses': 'Temporarily relieves minor aches and pains, reduces fever',
                    'warnings': 'Stomach bleeding warning. Do not use with other NSAIDs.',
                    'directions': 'Adults: take 1-2 capsules every 4-6 hours while symptoms persist',
                    'upc_code': '300450550200',
                    'search_keywords': ['advil', 'ibuprofen', 'pain', 'fever', 'inflammation']
                },
                {
                    'product_name': 'Aspirin 81mg',
                    'brand_name': 'Bayer',
                    'active_ingredients': ['Aspirin'],
                    'strength': '81 mg',
                    'dosage_form': 'Tablet',
                    'package_size': '120 tablets',
                    'manufacturer': manufacturers['bayer'],
                    'categories': [categories['cardiovascular'], categories['pain_relief']],
                    'purpose': 'Pain reliever/antiplatelet',
                    'uses': 'For reduction of risk of heart attack and stroke, minor pain relief',
                    'warnings': 'Consult doctor before use for cardiovascular protection',
                    'directions': 'For cardiovascular protection: take 1 tablet daily or as directed by doctor',
                    'upc_code': '312843536029',
                    'search_keywords': ['aspirin', 'bayer', 'heart', 'stroke', 'blood thinner']
                },
                {
                    'product_name': 'Robitussin DM',
                    'brand_name': 'Robitussin',
                    'active_ingredients': ['Dextromethorphan HBr', 'Guaifenesin'],
                    'strength': '15mg/200mg per 5mL',
                    'dosage_form': 'Liquid',
                    'package_size': '4 fl oz',
                    'manufacturer': manufacturers['pfizer'],
                    'categories': [categories['cold_flu']],
                    'purpose': 'Cough suppressant/Expectorant',
                    'uses': 'Temporarily relieves cough, helps loosen phlegm',
                    'warnings': 'Do not exceed recommended dose. Do not use with MAO inhibitors.',
                    'directions': 'Adults: take 2 teaspoons every 4 hours',
                    'upc_code': '300450261404',
                    'search_keywords': ['robitussin', 'cough', 'phlegm', 'cold', 'dextromethorphan']
                },
            ]
            
            for med_data in otc_meds:
                categories_list = med_data.pop('categories', [])
                med = OTCMedication.objects.create(**med_data)
                med.categories.set(categories_list)
            
            # Create sample supplements
            supplements = [
                {
                    'product_name': 'Vitamin D3 2000 IU',
                    'brand_name': 'Nature Made',
                    'supplement_ingredients': ['Vitamin D3 (Cholecalciferol)'],
                    'serving_size': '1 tablet',
                    'servings_per_container': '100',
                    'dosage_form': 'Tablet',
                    'manufacturer': manufacturers['nature_made'],
                    'categories': [categories['vitamins']],
                    'intended_use': 'Supports bone health and immune function',
                    'directions': 'Take 1 tablet daily with food',
                    'warnings': 'Do not exceed recommended dose. Consult physician if pregnant or nursing.',
                    'upc_code': '031604014025',
                    'search_keywords': ['vitamin d', 'vitamin d3', 'bone health', 'immune', 'cholecalciferol']
                },
                {
                    'product_name': 'Omega-3 Fish Oil',
                    'brand_name': 'Nature Made',
                    'supplement_ingredients': ['Fish Oil Concentrate', 'EPA', 'DHA'],
                    'serving_size': '2 softgels',
                    'servings_per_container': '90',
                    'dosage_form': 'Softgel',
                    'manufacturer': manufacturers['nature_made'],
                    'categories': [categories['cardiovascular']],
                    'intended_use': 'Supports heart health and brain function',
                    'directions': 'Take 2 softgels daily with meals',
                    'warnings': 'Consult physician if taking blood thinners',
                    'upc_code': '031604026721',
                    'search_keywords': ['omega 3', 'fish oil', 'epa', 'dha', 'heart health']
                },
                {
                    'product_name': 'Multivitamin Adult',
                    'brand_name': 'Nature Made',
                    'supplement_ingredients': [
                        'Vitamin A', 'Vitamin C', 'Vitamin D', 'Vitamin E', 
                        'B Vitamins', 'Iron', 'Calcium', 'Zinc'
                    ],
                    'serving_size': '1 tablet',
                    'servings_per_container': '100',
                    'dosage_form': 'Tablet',
                    'manufacturer': manufacturers['nature_made'],
                    'categories': [categories['vitamins']],
                    'intended_use': 'Provides essential vitamins and minerals for daily nutrition',
                    'directions': 'Take 1 tablet daily with food',
                    'warnings': 'Contains iron. Keep out of reach of children.',
                    'upc_code': '031604014872',
                    'search_keywords': ['multivitamin', 'daily vitamins', 'essential nutrients']
                },
                {
                    'product_name': 'Vitamin C 1000mg',
                    'brand_name': 'Nature Made',
                    'supplement_ingredients': ['Vitamin C (Ascorbic Acid)'],
                    'serving_size': '1 tablet',
                    'servings_per_container': '100',
                    'dosage_form': 'Tablet',
                    'manufacturer': manufacturers['nature_made'],
                    'categories': [categories['vitamins'], categories['immune']],
                    'intended_use': 'Supports immune system health and antioxidant protection',
                    'directions': 'Take 1 tablet daily with food',
                    'warnings': 'High doses may cause stomach upset in sensitive individuals',
                    'upc_code': '031604014018',
                    'search_keywords': ['vitamin c', 'ascorbic acid', 'immune support', 'antioxidant']
                },
            ]
            
            for supp_data in supplements:
                categories_list = supp_data.pop('categories', [])
                supp = Supplement.objects.create(**supp_data)
                supp.categories.set(categories_list)
        
        # Print summary
        self.stdout.write(
            self.style.SUCCESS(
                f'Sample data created successfully:\n'
                f'  Manufacturers: {Manufacturer.objects.count()}\n'
                f'  Categories: {DrugCategory.objects.count()}\n'
                f'  Prescription Medications: {PrescriptionMedication.objects.count()}\n'
                f'  OTC Medications: {OTCMedication.objects.count()}\n'
                f'  Supplements: {Supplement.objects.count()}'
            )
        )