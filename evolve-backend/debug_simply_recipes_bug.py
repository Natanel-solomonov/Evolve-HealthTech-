#!/usr/bin/env python3
import sys
import os
import django

# Setup Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from recipes.services.recipe_scraper import RecipeScraper
import traceback

def debug_simply_recipes():
    """Debug the Simply Recipes scraping bug."""
    scraper = RecipeScraper()
    
    # Test URL that was working before
    test_url = "https://www.simplyrecipes.com/recipes/how_to_grill_the_best_burgers/"
    
    print(f"Testing URL: {test_url}")
    print("="*60)
    
    try:
        # Get the raw HTML first
        response = scraper.session.get(test_url, timeout=30)
        response.raise_for_status()
        
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(response.content, 'html.parser')
        
        print("✅ Successfully got HTML")
        
        # Try to extract ingredients
        print("\n🔍 Testing ingredient extraction...")
        main_content = soup.find('article') or soup.find('main') or soup
        
        # Look for ingredients section heading followed by list
        headings = soup.find_all(['h2', 'h3', 'h4'], string=lambda x: x and 'ingredients' in x.lower())
        
        print(f"Found {len(headings)} ingredient headings")
        
        for i, heading in enumerate(headings):
            print(f"  Heading {i+1}: '{heading.get_text(strip=True)}'")
            
            # Find the next list after the ingredients heading
            next_list = heading.find_next(['ul', 'ol'])
            if next_list:
                print(f"  Found list with {len(next_list.find_all('li'))} items")
                
                for j, li in enumerate(next_list.find_all('li')[:3]):  # Test first 3
                    text = li.get_text(strip=True)
                    print(f"    Item {j+1}: '{text}'")
                    
                    if scraper._is_valid_ingredient_text(text):
                        print(f"    ✅ Valid ingredient text")
                        try:
                            parsed = scraper._parse_ingredient(text)
                            print(f"    Parsed: {parsed}")
                        except Exception as e:
                            print(f"    ❌ Parse error: {e}")
                            traceback.print_exc()
                    else:
                        print(f"    ❌ Invalid ingredient text")
                break
        
        # Try the full extraction
        print("\n🔍 Testing full extraction...")
        result = scraper._extract_simplyrecipes_data(soup, test_url)
        print(f"Title: {result.get('title', 'N/A')}")
        print(f"Ingredients count: {len(result.get('ingredients', []))}")
        print(f"Instructions count: {len(result.get('instructions', []))}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        traceback.print_exc()

if __name__ == "__main__":
    debug_simply_recipes() 