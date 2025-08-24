from django.contrib import admin
from .models import (
    DrugCategory, Manufacturer, PrescriptionMedication, 
    OTCMedication, Supplement, UserMedication, MedicationDose
)


@admin.register(DrugCategory)
class DrugCategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'parent_category', 'created_at')
    list_filter = ('parent_category', 'created_at')
    search_fields = ('name', 'description')
    ordering = ('name',)


@admin.register(Manufacturer)
class ManufacturerAdmin(admin.ModelAdmin):
    list_display = ('name', 'website', 'created_at')
    search_fields = ('name', 'description')
    ordering = ('name',)


@admin.register(PrescriptionMedication)
class PrescriptionMedicationAdmin(admin.ModelAdmin):
    list_display = ('brand_name', 'generic_name', 'manufacturer', 'ndc_number', 'approval_date', 'is_active')
    list_filter = ('manufacturer', 'dosage_form', 'route_of_administration', 'is_active', 'approval_date')
    search_fields = ('brand_name', 'generic_name', 'ndc_number', 'active_ingredients')
    filter_horizontal = ('categories',)
    ordering = ('brand_name',)
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('brand_name', 'generic_name', 'active_ingredients', 'manufacturer')
        }),
        ('FDA Data', {
            'fields': ('ndc_number', 'fda_application_number', 'approval_date')
        }),
        ('Drug Details', {
            'fields': ('strength', 'dosage_form', 'route_of_administration', 'categories')
        }),
        ('Label Information', {
            'fields': ('drug_label_text', 'indications', 'contraindications', 'warnings_precautions', 'side_effects', 'dosage_instructions')
        }),
        ('Images', {
            'fields': ('label_image_url', 'pill_image_url')
        }),
        ('Search & Status', {
            'fields': ('is_active', 'search_keywords')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )


@admin.register(OTCMedication)
class OTCMedicationAdmin(admin.ModelAdmin):
    list_display = ('product_name', 'brand_name', 'manufacturer', 'upc_code', 'is_active')
    list_filter = ('manufacturer', 'dosage_form', 'otc_monograph', 'is_active')
    search_fields = ('product_name', 'brand_name', 'upc_code', 'active_ingredients')
    filter_horizontal = ('categories',)
    ordering = ('product_name',)
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('product_name', 'brand_name', 'active_ingredients', 'inactive_ingredients', 'manufacturer')
        }),
        ('Product Details', {
            'fields': ('strength', 'dosage_form', 'package_size', 'categories')
        }),
        ('OTC Classification', {
            'fields': ('otc_monograph', 'upc_code')
        }),
        ('Drug Facts', {
            'fields': ('drug_facts', 'purpose', 'uses', 'warnings', 'directions', 'other_information')
        }),
        ('Images', {
            'fields': ('label_image_url', 'package_image_url')
        }),
        ('Search & Status', {
            'fields': ('is_active', 'search_keywords')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )


@admin.register(Supplement)
class SupplementAdmin(admin.ModelAdmin):
    list_display = ('product_name', 'brand_name', 'manufacturer', 'upc_code', 'is_active')
    list_filter = ('manufacturer', 'dosage_form', 'is_active')
    search_fields = ('product_name', 'brand_name', 'upc_code', 'supplement_ingredients')
    filter_horizontal = ('categories',)
    ordering = ('product_name',)
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('product_name', 'brand_name', 'supplement_ingredients', 'other_ingredients', 'manufacturer')
        }),
        ('Product Details', {
            'fields': ('serving_size', 'servings_per_container', 'dosage_form', 'categories')
        }),
        ('Supplement Classification', {
            'fields': ('upc_code',)
        }),
        ('Supplement Facts', {
            'fields': ('supplement_facts', 'intended_use', 'directions', 'warnings', 'other_information')
        }),
        ('Images', {
            'fields': ('label_image_url', 'package_image_url')
        }),
        ('Search & Status', {
            'fields': ('is_active', 'search_keywords')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )


@admin.register(UserMedication)
class UserMedicationAdmin(admin.ModelAdmin):
    list_display = ('user', 'get_medication_name', 'dosage', 'frequency', 'start_date', 'is_active')
    list_filter = ('is_active', 'start_date', 'end_date')
    search_fields = ('user__phone', 'custom_name', 'prescribing_doctor')
    ordering = ('-created_at',)
    readonly_fields = ('created_at', 'updated_at')
    
    def get_medication_name(self, obj):
        if obj.custom_name:
            return obj.custom_name
        elif obj.prescription_medication:
            return obj.prescription_medication.brand_name
        elif obj.otc_medication:
            return obj.otc_medication.product_name
        elif obj.supplement:
            return obj.supplement.product_name
        return "Unknown"
    get_medication_name.short_description = 'Medication'


@admin.register(MedicationDose)
class MedicationDoseAdmin(admin.ModelAdmin):
    list_display = ('user_medication', 'scheduled_time', 'taken_time', 'was_taken')
    list_filter = ('was_taken', 'scheduled_time')
    search_fields = ('user_medication__user__phone',)
    ordering = ('-scheduled_time',)
    readonly_fields = ('created_at', 'updated_at')