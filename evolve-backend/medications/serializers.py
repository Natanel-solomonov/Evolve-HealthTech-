from rest_framework import serializers
from .models import (
    DrugCategory, Manufacturer, PrescriptionMedication, 
    OTCMedication, Supplement, UserMedication, MedicationDose
)


class DrugCategorySerializer(serializers.ModelSerializer):
    """Serializer for drug categories"""
    class Meta:
        model = DrugCategory
        fields = ['id', 'name', 'description', 'parent_category']


class ManufacturerSerializer(serializers.ModelSerializer):
    """Serializer for manufacturers"""
    class Meta:
        model = Manufacturer
        fields = ['id', 'name', 'description', 'website']


class PrescriptionMedicationSerializer(serializers.ModelSerializer):
    """Serializer for prescription medications"""
    manufacturer = ManufacturerSerializer(read_only=True)
    categories = DrugCategorySerializer(many=True, read_only=True)
    
    class Meta:
        model = PrescriptionMedication
        fields = [
            'id', 'brand_name', 'generic_name', 'active_ingredients',
            'ndc_number', 'fda_application_number', 'approval_date',
            'strength', 'dosage_form', 'route_of_administration',
            'manufacturer', 'categories', 'drug_label_text',
            'indications', 'contraindications', 'warnings_precautions',
            'side_effects', 'dosage_instructions', 'label_image_url',
            'pill_image_url', 'is_active', 'search_keywords'
        ]


class PrescriptionMedicationSearchSerializer(serializers.ModelSerializer):
    """Lightweight serializer for search results"""
    manufacturer_name = serializers.CharField(source='manufacturer.name', read_only=True)
    
    class Meta:
        model = PrescriptionMedication
        fields = [
            'id', 'brand_name', 'generic_name', 'active_ingredients',
            'ndc_number', 'strength', 'dosage_form', 'manufacturer_name',
            'label_image_url', 'pill_image_url'
        ]


class OTCMedicationSerializer(serializers.ModelSerializer):
    """Serializer for OTC medications"""
    manufacturer = ManufacturerSerializer(read_only=True)
    categories = DrugCategorySerializer(many=True, read_only=True)
    
    class Meta:
        model = OTCMedication
        fields = [
            'id', 'product_name', 'brand_name', 'active_ingredients',
            'inactive_ingredients', 'strength', 'dosage_form', 'package_size',
            'manufacturer', 'categories', 'otc_monograph', 'upc_code',
            'drug_facts', 'purpose', 'uses', 'warnings', 'directions',
            'other_information', 'label_image_url', 'package_image_url',
            'is_active', 'search_keywords'
        ]


class OTCMedicationSearchSerializer(serializers.ModelSerializer):
    """Lightweight serializer for search results"""
    manufacturer_name = serializers.CharField(source='manufacturer.name', read_only=True)
    
    class Meta:
        model = OTCMedication
        fields = [
            'id', 'product_name', 'brand_name', 'active_ingredients',
            'strength', 'dosage_form', 'manufacturer_name', 'upc_code',
            'purpose', 'label_image_url', 'package_image_url'
        ]


class SupplementSerializer(serializers.ModelSerializer):
    """Serializer for supplements"""
    manufacturer = ManufacturerSerializer(read_only=True)
    categories = DrugCategorySerializer(many=True, read_only=True)
    
    class Meta:
        model = Supplement
        fields = [
            'id', 'product_name', 'brand_name', 'supplement_ingredients',
            'other_ingredients', 'serving_size', 'servings_per_container',
            'dosage_form', 'manufacturer', 'categories', 'supplement_facts',
            'upc_code', 'intended_use', 'directions', 'warnings',
            'other_information', 'label_image_url', 'package_image_url',
            'is_active', 'search_keywords'
        ]


class SupplementSearchSerializer(serializers.ModelSerializer):
    """Lightweight serializer for search results"""
    manufacturer_name = serializers.CharField(source='manufacturer.name', read_only=True)
    
    class Meta:
        model = Supplement
        fields = [
            'id', 'product_name', 'brand_name', 'supplement_ingredients',
            'serving_size', 'dosage_form', 'manufacturer_name', 'upc_code',
            'intended_use', 'label_image_url', 'package_image_url'
        ]


class UserMedicationSerializer(serializers.ModelSerializer):
    """Serializer for user's personal medications"""
    prescription_medication = PrescriptionMedicationSearchSerializer(read_only=True)
    otc_medication = OTCMedicationSearchSerializer(read_only=True)
    supplement = SupplementSearchSerializer(read_only=True)
    
    class Meta:
        model = UserMedication
        fields = [
            'id', 'prescription_medication', 'otc_medication', 'supplement',
            'custom_name', 'dosage', 'frequency', 'start_date', 'end_date',
            'is_active', 'notes', 'prescribing_doctor', 'created_at'
        ]


class UserMedicationCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating user medications"""
    
    class Meta:
        model = UserMedication
        fields = [
            'prescription_medication', 'otc_medication', 'supplement',
            'custom_name', 'dosage', 'frequency', 'start_date', 'end_date',
            'notes', 'prescribing_doctor'
        ]

    def validate(self, data):
        """Ensure exactly one medication type is provided"""
        medication_fields = ['prescription_medication', 'otc_medication', 'supplement']
        provided_medications = [field for field in medication_fields if data.get(field)]
        
        if len(provided_medications) != 1:
            raise serializers.ValidationError(
                "Exactly one medication type (prescription_medication, otc_medication, or supplement) must be provided."
            )
        
        return data

    def create(self, validated_data):
        # Set the user from the request context
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)


class MedicationDoseSerializer(serializers.ModelSerializer):
    """Serializer for medication doses"""
    user_medication = UserMedicationSerializer(read_only=True)
    
    class Meta:
        model = MedicationDose
        fields = [
            'id', 'user_medication', 'scheduled_time', 'taken_time',
            'was_taken', 'notes', 'created_at'
        ]


class MedicationDoseCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating medication doses"""
    
    class Meta:
        model = MedicationDose
        fields = [
            'user_medication', 'scheduled_time', 'taken_time',
            'was_taken', 'notes'
        ]