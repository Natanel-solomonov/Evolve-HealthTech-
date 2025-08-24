#!/usr/bin/env python3
"""
Script to show admin panel access information for recipes
"""
import os
import sys
import django
from pathlib import Path

# Add the project root to Python path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')

# Configure for Railway production database
os.environ['DATABASE_URL'] = 'postgresql://postgres:qnnGfLhKCumgpFRzKoOvPbTtsDWIYiwp@shinkansen.proxy.rlwy.net:37235/railway'
os.environ['RAILWAY_ENVIRONMENT'] = 'production'

# Initialize Django
django.setup()

from django.contrib.auth import get_user_model
from recipes.models import Recipe, RecipeIngredient, InstructionStep, Ingredient, Equipment
from backend.settings import ADMIN_URL_PREFIX

User = get_user_model()

def main():
    print("🔐 DJANGO ADMIN PANEL ACCESS INFORMATION")
    print("=" * 60)
    
    # Get recipe counts
    total_recipes = Recipe.objects.count()
    total_ingredients = Ingredient.objects.count()
    total_equipment = Equipment.objects.count()
    
    print(f"📊 DATABASE STATS:")
    print(f"   • Total Recipes: {total_recipes}")
    print(f"   • Total Ingredients: {total_ingredients}")
    print(f"   • Total Equipment: {total_equipment}")
    
    print(f"\n🌐 ADMIN PANEL URLS:")
    print(f"   • Local Development: http://localhost:8000/{ADMIN_URL_PREFIX}")
    print(f"   • Railway Production: https://your-railway-domain.railway.app/{ADMIN_URL_PREFIX}")
    
    print(f"\n📋 RECIPE ADMIN SECTIONS:")
    print(f"   • Recipes: /{ADMIN_URL_PREFIX}recipes/recipe/")
    print(f"   • Ingredients: /{ADMIN_URL_PREFIX}recipes/ingredient/")
    print(f"   • Equipment: /{ADMIN_URL_PREFIX}recipes/equipment/")
    print(f"   • Recipe Ingredients: /{ADMIN_URL_PREFIX}recipes/recipeingredient/")
    print(f"   • Instruction Steps: /{ADMIN_URL_PREFIX}recipes/instructionstep/")
    print(f"   • Recipe Nutrition: /{ADMIN_URL_PREFIX}recipes/recipenutrition/")
    
    # Check for superuser accounts
    superusers = User.objects.filter(is_superuser=True)
    if superusers.exists():
        print(f"\n👤 SUPERUSER ACCOUNTS:")
        for user in superusers:
            # Handle custom AppUser model
            username = getattr(user, 'username', getattr(user, 'phone_number', 'N/A'))
            email = getattr(user, 'email', 'N/A')
            phone = getattr(user, 'phone_number', 'N/A')
            print(f"   • Username/Phone: {username}")
            print(f"   • Email: {email}")
            print(f"   • Phone: {phone}")
    else:
        print(f"\n❌ NO SUPERUSER ACCOUNTS FOUND")
        print(f"   Create one with: python manage.py createsuperuser")
    
    print(f"\n🔧 HOW TO ACCESS:")
    print(f"   1. Go to the admin URL above")
    print(f"   2. Log in with your superuser credentials")
    print(f"   3. Click on 'Recipes' in the admin panel")
    print(f"   4. You'll see all {total_recipes} recipes listed")
    print(f"   5. Click on any recipe to view/edit its details")
    
    print(f"\n📱 RAILWAY PRODUCTION ACCESS:")
    print(f"   • Your Railway app should be accessible at your Railway domain")
    print(f"   • The admin panel will be at: your-domain.railway.app/{ADMIN_URL_PREFIX}")
    print(f"   • Make sure your Railway app is deployed and running")
    
    # Show some sample recipes
    print(f"\n🍳 SAMPLE RECIPES IN DATABASE:")
    sample_recipes = Recipe.objects.all()[:5]
    for i, recipe in enumerate(sample_recipes, 1):
        print(f"   {i}. {recipe.title} (ID: {recipe.id})")
        print(f"      Source: {recipe.source_name}")
        print(f"      Created: {recipe.created_at}")

if __name__ == "__main__":
    main() 