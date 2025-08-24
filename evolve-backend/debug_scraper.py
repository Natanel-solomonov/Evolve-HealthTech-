#!/usr/bin/env python3
import sys
import os
import django
import json
import requests
from bs4 import BeautifulSoup

# Setup Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from recipes.services.recipe_scraper import RecipeScraper

def debug_html_structure(url, site_name):
    """Debug the HTML structure of a recipe page."""
    print(f"\n{'='*60}")
    print(f"DEBUGGING {site_name.upper()}")
    print(f"{'='*60}")
    print(f"URL: {url}")
    
    scraper = RecipeScraper()
    
    try:
        response = scraper.session.get(url, timeout=30)
        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')
        
        print(f"\nStatus Code: {response.status_code}")
        print(f"Content Length: {len(response.content)} bytes")
        
        # Check for JSON-LD
        json_ld_scripts = soup.find_all('script', type='application/ld+json')
        print(f"\nJSON-LD Scripts Found: {len(json_ld_scripts)}")
        
        for i, script in enumerate(json_ld_scripts):
            try:
                data = json.loads(script.string)
                print(f"  Script {i+1}: {type(data)} - {str(data)[:100]}...")
            except:
                print(f"  Script {i+1}: Invalid JSON")
        
        # Check for title
        print(f"\nTITLE SELECTORS:")
        title_selectors = [
            'h1.recipe-summary__h1',
            'h1[data-testid="recipe-title"]',
            '.recipe-title h1',
            'h1.entry-title',
            'h1.recipe-title',
            'h1',
            '.post-title h1'
        ]
        
        for selector in title_selectors:
            element = soup.select_one(selector)
            if element:
                title = element.get_text(strip=True)
                print(f"  {selector}: '{title}'")
            else:
                print(f"  {selector}: NOT FOUND")
        
        # Check for ingredients
        print(f"\nINGREDIENTS SELECTORS:")
        ingredient_selectors = [
            '[data-testid="recipe-ingredients"] li span',
            '.recipe-ingredients li span',
            '.ingredients-item-name',
            '.ingredients-section span',
            '.recipe-ingredient',
            'ul.ingredients li span'
        ]
        
        for selector in ingredient_selectors:
            elements = soup.select(selector)
            if elements:
                print(f"  {selector}: {len(elements)} elements found")
                for i, elem in enumerate(elements[:3]):  # Show first 3
                    text = elem.get_text(strip=True)
                    print(f"    {i+1}. '{text}'")
                if len(elements) > 3:
                    print(f"    ... and {len(elements) - 3} more")
            else:
                print(f"  {selector}: NOT FOUND")
        
        # Check for instructions
        print(f"\nINSTRUCTIONS SELECTORS:")
        instruction_selectors = [
            '[data-testid="recipe-instructions"] li',
            '.recipe-instructions li',
            '.instructions-section li',
            '.recipe-directions li',
            'ol.instructions li'
        ]
        
        for selector in instruction_selectors:
            elements = soup.select(selector)
            if elements:
                print(f"  {selector}: {len(elements)} elements found")
                for i, elem in enumerate(elements[:3]):  # Show first 3
                    text = elem.get_text(strip=True)
                    print(f"    {i+1}. '{text[:100]}...'")
                if len(elements) > 3:
                    print(f"    ... and {len(elements) - 3} more")
            else:
                print(f"  {selector}: NOT FOUND")
        
        # Look for ingredients heading and list (Simply Recipes style)
        print(f"\nSIMPLY RECIPES STYLE INGREDIENTS:")
        headings = soup.find_all(['h2', 'h3', 'h4'], string=lambda text: text and 'ingredient' in text.lower())
        print(f"  Ingredients headings found: {len(headings)}")
        
        for i, heading in enumerate(headings):
            print(f"  Heading {i+1}: '{heading.get_text(strip=True)}'")
            next_list = heading.find_next(['ul', 'ol'])
            if next_list:
                items = next_list.find_all('li')
                print(f"    Next list: {len(items)} items")
                for j, item in enumerate(items[:3]):
                    text = item.get_text(strip=True)
                    print(f"      {j+1}. '{text}'")
                if len(items) > 3:
                    print(f"      ... and {len(items) - 3} more")
            else:
                print(f"    No list found after heading")
        
        # Look for method/instructions headings (Simply Recipes style)
        print(f"\nSIMPLY RECIPES STYLE INSTRUCTIONS:")
        method_terms = ['method', 'instructions', 'directions']
        for term in method_terms:
            headings = soup.find_all(['h2', 'h3', 'h4'], string=lambda text: text and term in text.lower())
            print(f"  '{term}' headings found: {len(headings)}")
            
            for i, heading in enumerate(headings):
                print(f"  '{term}' heading {i+1}: '{heading.get_text(strip=True)}'")
                next_element = heading.find_next_sibling()
                if next_element:
                    print(f"    Next element: {next_element.name} - '{next_element.get_text(strip=True)[:100]}...'")
                    # Print the HTML for inspection (only for Simply Recipes)
                    if site_name.lower().startswith('simply'):
                        print(f"    --- HTML of next_element ---\n{str(next_element)[:1000]}\n--- END HTML ---")
                        # Write full HTML to file for inspection
                        try:
                            with open('debug_method_section.html', 'w', encoding='utf-8') as f:
                                f.write(str(next_element))
                            print(f"    Full HTML written to debug_method_section.html")
                        except Exception as e:
                            print(f"    Error writing HTML file: {e}")
                else:
                    print(f"    No next element found")
                    # Try to find any siblings
                    siblings = list(heading.next_siblings)
                    print(f"    Siblings found: {len(siblings)}")
                    for j, sibling in enumerate(siblings[:3]):
                        if hasattr(sibling, 'name'):
                            print(f"      Sibling {j+1}: {sibling.name} - '{sibling.get_text(strip=True)[:50]}...'")
        
        # Try the actual scraper
        print(f"\n{'='*60}")
        print("ACTUAL SCRAPER RESULTS")
        print(f"{'='*60}")
        
        result = scraper.scrape_recipe(url)
        print(json.dumps(result, indent=2, ensure_ascii=False))
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

def main():
    # Test URLs
    allrecipes_url = "https://www.allrecipes.com/recipe/25473/the-perfect-basic-burger/"
    simply_url = "https://www.simplyrecipes.com/recipes/how_to_grill_the_best_burgers/"
    
    debug_html_structure(allrecipes_url, "AllRecipes")
    debug_html_structure(simply_url, "Simply Recipes")

if __name__ == "__main__":
    main() 