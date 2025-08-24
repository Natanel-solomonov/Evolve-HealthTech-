from django.contrib import admin
from django.utils.html import format_html
from .models import (
    Ingredient, Equipment, Recipe, RecipeIngredient, 
    InstructionStep, RecipeNutrition
)


@admin.register(Ingredient)
class IngredientAdmin(admin.ModelAdmin):
    list_display = ['name', 'description', 'created_at']
    list_filter = ['created_at']
    search_fields = ['name', 'description']
    ordering = ['name']
    readonly_fields = ['id', 'created_at', 'updated_at']


@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = ['name', 'size', 'description', 'created_at']
    list_filter = ['created_at']
    search_fields = ['name', 'size', 'description']
    ordering = ['name']
    readonly_fields = ['id', 'created_at', 'updated_at']


class RecipeIngredientInline(admin.TabularInline):
    model = RecipeIngredient
    extra = 1
    fields = ['ingredient', 'quantity', 'unit', 'notes', 'order']
    ordering = ['order']


class InstructionStepInline(admin.TabularInline):
    model = InstructionStep
    extra = 1
    fields = ['order', 'template']
    ordering = ['order']


@admin.register(Recipe)
class RecipeAdmin(admin.ModelAdmin):
    list_display = [
        'title', 'difficulty', 'total_time', 'servings', 
        'cuisine', 'source_name', 'created_at'
    ]
    list_filter = ['difficulty', 'cuisine', 'created_at', 'tags']
    search_fields = ['title', 'description', 'source_name']
    readonly_fields = ['id', 'created_at', 'updated_at']
    prepopulated_fields = {'tags': []}
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('title', 'description', 'image_url')
        }),
        ('Timing & Servings', {
            'fields': ('prep_time', 'cook_time', 'total_time', 'servings')
        }),
        ('Classification', {
            'fields': ('difficulty', 'cuisine', 'tags')
        }),
        ('Source Information', {
            'fields': ('source_url', 'source_name'),
            'classes': ('collapse',)
        }),
        ('Metadata', {
            'fields': ('id', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    inlines = [RecipeIngredientInline, InstructionStepInline]


@admin.register(RecipeIngredient)
class RecipeIngredientAdmin(admin.ModelAdmin):
    list_display = ['recipe', 'ingredient', 'quantity', 'unit', 'order']
    list_filter = ['unit', 'created_at']
    search_fields = ['recipe__title', 'ingredient__name']
    ordering = ['recipe', 'order']
    readonly_fields = ['id', 'created_at']


@admin.register(InstructionStep)
class InstructionStepAdmin(admin.ModelAdmin):
    list_display = ['recipe', 'order', 'template_preview', 'ingredients_count', 'equipment_count']
    list_filter = ['created_at']
    search_fields = ['recipe__title', 'template']
    ordering = ['recipe', 'order']
    readonly_fields = ['id', 'created_at']
    
    def template_preview(self, obj):
        """Show a preview of the template text."""
        return obj.template[:100] + "..." if len(obj.template) > 100 else obj.template
    template_preview.short_description = "Template Preview"
    
    def ingredients_count(self, obj):
        """Show count of linked ingredients."""
        return obj.ingredients.count()
    ingredients_count.short_description = "Ingredients"
    
    def equipment_count(self, obj):
        """Show count of linked equipment."""
        return obj.equipment.count()
    equipment_count.short_description = "Equipment"


@admin.register(RecipeNutrition)
class RecipeNutritionAdmin(admin.ModelAdmin):
    list_display = ['recipe', 'calories', 'protein', 'carbs', 'fat', 'fiber']
    list_filter = ['created_at']
    search_fields = ['recipe__title']
    readonly_fields = ['id', 'created_at', 'updated_at']
    
    fieldsets = (
        ('Recipe', {
            'fields': ('recipe',)
        }),
        ('Macronutrients', {
            'fields': ('calories', 'protein', 'carbs', 'fat')
        }),
        ('Other Nutrients', {
            'fields': ('fiber', 'sugar', 'sodium')
        }),
        ('Metadata', {
            'fields': ('id', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
