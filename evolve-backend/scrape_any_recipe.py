#!/usr/bin/env python3
import sys
import os
import django
import json

# Setup Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from recipes.services.recipe_scraper import scrape_recipe_from_url

def scrape_recipe(url):
    """Scrape any recipe URL and return the results."""
    print(f"Scraping recipe from: {url}")
    print("=" * 60)
    
    try:
        result = scrape_recipe_from_url(url)
        
        # Print the full JSON result
        print(json.dumps(result, indent=2, ensure_ascii=False))
        
        # Print summary
        print("\n" + "=" * 60)
        print("SUMMARY")
        print("=" * 60)
        print(f"Title: {result.get('title', 'N/A')}")
        print(f"Ingredients: {len(result.get('ingredients', []))}")
        print(f"Instructions: {len(result.get('instructions', []))}")
        print(f"Equipment: {len(result.get('equipment', []))}")
        print(f"Prep Time: {result.get('prep_time', 'N/A')} minutes")
        print(f"Cook Time: {result.get('cook_time', 'N/A')} minutes")
        print(f"Total Time: {result.get('total_time', 'N/A')} minutes")
        print(f"Servings: {result.get('servings', 'N/A')}")
        print(f"Source: {result.get('source_name', 'N/A')}")
        
        return result
        
    except Exception as e:
        print(f"Error scraping recipe: {e}")
        import traceback
        traceback.print_exc()
        return None

def main():
    """Main function to handle command line arguments or interactive input."""
    if len(sys.argv) > 1:
        # URL provided as command line argument
        url = sys.argv[1]
        scrape_recipe(url)
    else:
        # Interactive mode
        print("Recipe Scraper - Interactive Mode")
        print("=" * 40)
        print("Enter a recipe URL to scrape (or 'quit' to exit):")
        
        while True:
            url = input("\nURL: ").strip()
            
            if url.lower() in ['quit', 'exit', 'q']:
                print("Goodbye!")
                break
                
            if not url:
                print("Please enter a valid URL.")
                continue
                
            if not url.startswith(('http://', 'https://')):
                print("Please enter a valid URL starting with http:// or https://")
                continue
            
            scrape_recipe(url)
            
            print("\n" + "-" * 40)
            print("Enter another URL or 'quit' to exit:")

if __name__ == "__main__":
    main() 