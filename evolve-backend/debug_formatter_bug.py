#!/usr/bin/env python3
import sys
import os
import django

# Setup Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from recipes.services.recipe_scraper import RecipeScraper
from recipes.services.recipe_formatter import RecipeFormatter
import traceback

def debug_formatter():
    """Debug the formatter bug."""
    scraper = RecipeScraper()
    formatter = RecipeFormatter()
    
    # Test URL
    test_url = "https://www.simplyrecipes.com/recipes/how_to_grill_the_best_burgers/"
    
    print(f"Testing URL: {test_url}")
    print("="*60)
    
    try:
        # Scrape the recipe
        scraped_data = scraper.scrape_recipe(test_url)
        print("✅ Successfully scraped recipe")
        print(f"Title: {scraped_data.get('title', 'N/A')}")
        print(f"Ingredients count: {len(scraped_data.get('ingredients', []))}")
        print(f"Instructions count: {len(scraped_data.get('instructions', []))}")
        
        # Show first few ingredients
        print("\nFirst 3 ingredients:")
        for i, ing in enumerate(scraped_data.get('ingredients', [])[:3]):
            print(f"  {i+1}. {ing}")
        
        # Try to format the recipe
        print("\n🔍 Testing formatter...")
        recipe = formatter.format_recipe_from_scraped_data(scraped_data)
        print(f"✅ Successfully created recipe: {recipe.title}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        traceback.print_exc()

if __name__ == "__main__":
    debug_formatter() 