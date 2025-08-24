#!/usr/bin/env python3
"""
Display 30 random recipes from Railway production database
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

from django.db import connection
from recipes.models import Recipe, RecipeIngredient, InstructionStep, Ingredient, Equipment
import random


def display_recipe_summary(recipe, index):
    """Display a concise recipe summary"""
    print(f"\n{'='*80}")
    print(f"🍳 RECIPE #{index}: {recipe.title}")
    print(f"{'='*80}")
    print(f"📰 Source: {recipe.source_name or 'Unknown'}")
    print(f"🔗 URL: {recipe.source_url or 'N/A'}")
    
    if recipe.description:
        print(f"📖 Description: {recipe.description[:100]}...")
    
    # Timing info
    timing_parts = []
    if recipe.prep_time:
        timing_parts.append(f"Prep: {recipe.prep_time}min")
    if recipe.cook_time:
        timing_parts.append(f"Cook: {recipe.cook_time}min")
    if recipe.total_time:
        timing_parts.append(f"Total: {recipe.total_time}min")
    if timing_parts:
        print(f"⏱️  Time: {' | '.join(timing_parts)}")
    
    if recipe.servings:
        print(f"👥 Servings: {recipe.servings}")
    if recipe.difficulty:
        print(f"📊 Difficulty: {recipe.difficulty.title()}")
    if recipe.cuisine:
        print(f"🌍 Cuisine: {recipe.cuisine}")
    
    # Ingredients count
    ingredient_count = recipe.recipe_ingredients.count()
    print(f"🥘 Ingredients: {ingredient_count}")
    
    # Instructions count
    step_count = recipe.steps.count()
    print(f"📋 Instructions: {step_count} steps")
    
    # Show first few ingredients
    if ingredient_count > 0:
        print(f"\n🥘 SAMPLE INGREDIENTS:")
        for ri in recipe.recipe_ingredients.all()[:5]:  # Show first 5
            print(f"  • {ri.quantity} {ri.unit} {ri.ingredient.name}")
        if ingredient_count > 5:
            print(f"  ... and {ingredient_count - 5} more ingredients")
    
    # Show first instruction
    if step_count > 0:
        first_step = recipe.steps.first()
        if first_step:
            rendered_step = first_step.render()
            print(f"\n📋 FIRST INSTRUCTION:")
            print(f"  1. {rendered_step[:150]}...")
    
    print(f"\n📅 Created: {recipe.created_at}")
    print(f"🆔 ID: {recipe.id}")


def get_random_recipes(count=30):
    """Get random recipes from the database"""
    # Get all recipe IDs first
    recipe_ids = list(Recipe.objects.values_list('id', flat=True))
    
    if not recipe_ids:
        return []
    
    # Select random IDs
    if len(recipe_ids) <= count:
        selected_ids = recipe_ids
    else:
        selected_ids = random.sample(recipe_ids, count)
    
    # Get the actual recipes with related data
    recipes = Recipe.objects.filter(id__in=selected_ids).prefetch_related(
        'recipe_ingredients__ingredient',
        'steps'
    )
    
    return list(recipes)


def main():
    print(f"🔌 Connecting to Railway production database...")
    print(f"🎲 Fetching 30 random recipes...")
    
    try:
        # Get total count first
        total_recipes = Recipe.objects.count()
        print(f"📊 Total recipes in database: {total_recipes}")
        
        if total_recipes == 0:
            print("❌ No recipes found in the database.")
            return
        
        # Get random recipes
        recipes = get_random_recipes(30)
        
        if not recipes:
            print("❌ No recipes found.")
            return
        
        print(f"\n🎯 Displaying {len(recipes)} random recipes:")
        
        for i, recipe in enumerate(recipes, 1):
            display_recipe_summary(recipe, i)
        
        # Show database connection info
        print(f"\n{'='*80}")
        print("🔗 DATABASE CONNECTION INFO:")
        print(f"🗄️  Database: {connection.settings_dict['NAME']}")
        print(f"🌐 Host: {connection.settings_dict['HOST']}")
        print(f"🔌 Port: {connection.settings_dict['PORT']}")
        print(f"👤 User: {connection.settings_dict['USER']}")
        
    except Exception as e:
        print(f"❌ Error connecting to database: {str(e)}")
        print("🔧 Make sure you have the correct database settings and connection.")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main() 