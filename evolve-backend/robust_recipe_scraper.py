#!/usr/bin/env python3
import sys
import os
import django
import json
import time
import requests
import re
from typing import List, Dict, Set
from dataclasses import dataclass
import logging
from datetime import datetime

# Setup Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from recipes.services.recipe_formatter import format_recipe_from_url
from recipes.models import Recipe

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class ScrapingStats:
    """Track scraping statistics."""
    total_urls_found: int = 0
    urls_scraped: int = 0
    successful_scrapes: int = 0
    failed_scrapes: int = 0
    start_time: datetime = None
    last_success_time: datetime = None
    
    def success_rate(self) -> float:
        """Calculate success rate."""
        if self.urls_scraped == 0:
            return 0.0
        return (self.successful_scrapes / self.urls_scraped) * 100
    
    def elapsed_hours(self) -> float:
        """Calculate elapsed time in hours."""
        if not self.start_time:
            return 0.0
        return (datetime.now() - self.start_time).total_seconds() / 3600

class RobustRecipeURLFinder:
    """Find recipe URLs using multiple strategies."""
    
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        })
    
    def get_known_working_urls(self) -> List[str]:
        """Get a list of known working recipe URLs for testing."""
        return [
            # AllRecipes - known working URLs
            "https://www.allrecipes.com/recipe/25473/the-perfect-basic-burger/",
            "https://www.allrecipes.com/recipe/16895/fluffy-french-toast/",
            "https://www.allrecipes.com/recipe/282923/baked-lobster-tails/",
            "https://www.allrecipes.com/recipe/24074/classic-macaroni-and-cheese/",
            "https://www.allrecipes.com/recipe/23600/worlds-best-lasagna/",
            "https://www.allrecipes.com/recipe/21412/grilled-cheese-sandwich/",
            "https://www.allrecipes.com/recipe/20144/banana-banana-bread/",
            "https://www.allrecipes.com/recipe/143069/super-delicious-zuppa-toscana/",
            "https://www.allrecipes.com/recipe/24433/creamy-au-gratin-potatoes/",
            "https://www.allrecipes.com/recipe/26317/chicken-marsala/",
            
            # Simply Recipes - known working URLs
            "https://www.simplyrecipes.com/recipes/how_to_grill_the_best_burgers/",
            "https://www.simplyrecipes.com/recipes/easy_steak_au_poivre_recipe_8785647/",
            "https://www.simplyrecipes.com/recipes/broccoli_cheddar_soup/",
            "https://www.simplyrecipes.com/recipes/classic_meatloaf/",
            "https://www.simplyrecipes.com/recipes/salmon_with_brown_sugar_glaze/",
            "https://www.simplyrecipes.com/recipes/italian_meatballs/",
            "https://www.simplyrecipes.com/recipes/sheet_pan_gnocchi/",
            "https://www.simplyrecipes.com/recipes/pesto_pasta_salad/",
            "https://www.simplyrecipes.com/recipes/homemade_pizza/",
            "https://www.simplyrecipes.com/recipes/steak_au_poivre/",
        ]
    
    def generate_allrecipes_urls(self, start_id: int = 25473, count: int = 100) -> List[str]:
        """Generate AllRecipes URLs by trying different recipe IDs."""
        urls = []
        print(f"Generating AllRecipes URLs starting from ID {start_id}...")
        
        for i in range(count):
            recipe_id = start_id + i
            # Try different URL patterns
            url_patterns = [
                f"https://www.allrecipes.com/recipe/{recipe_id}/",
                f"https://www.allrecipes.com/recipe/{recipe_id}/recipe/",
                f"https://www.allrecipes.com/recipe/{recipe_id}/the-perfect-basic-burger/",
            ]
            
            for pattern in url_patterns:
                urls.append(pattern)
        
        print(f"  Generated {len(urls)} AllRecipes URLs")
        return urls
    
    def get_simplyrecipes_sitemap_urls(self) -> List[str]:
        """Get URLs from Simply Recipes sitemap."""
        urls = []
        print("Checking Simply Recipes sitemap...")
        
        try:
            # Try to get sitemap
            sitemap_urls = [
                "https://www.simplyrecipes.com/sitemap.xml",
                "https://www.simplyrecipes.com/recipes-sitemap.xml",
                "https://www.simplyrecipes.com/sitemap_index.xml"
            ]
            
            for sitemap_url in sitemap_urls:
                try:
                    response = self.session.get(sitemap_url, timeout=10)
                    if response.status_code == 200:
                        # Extract recipe URLs from sitemap
                        recipe_urls = re.findall(r'<loc>(https://www\.simplyrecipes\.com/recipes/[^<]+)</loc>', response.text)
                        urls.extend(recipe_urls)
                        print(f"  Found {len(recipe_urls)} URLs in {sitemap_url}")
                        break
                except Exception as e:
                    print(f"  Error with {sitemap_url}: {e}")
                    continue
            
        except Exception as e:
            print(f"  Error getting sitemap: {e}")
        
        return urls
    
    def get_allrecipes_sitemap_urls(self) -> List[str]:
        """Get URLs from AllRecipes sitemap."""
        urls = []
        print("Checking AllRecipes sitemap...")
        
        try:
            sitemap_urls = [
                "https://www.allrecipes.com/sitemap.xml",
                "https://www.allrecipes.com/recipe-sitemap.xml",
                "https://www.allrecipes.com/sitemap_index.xml"
            ]
            
            for sitemap_url in sitemap_urls:
                try:
                    response = self.session.get(sitemap_url, timeout=10)
                    if response.status_code == 200:
                        # Extract recipe URLs from sitemap
                        recipe_urls = re.findall(r'<loc>(https://www\.allrecipes\.com/recipe/\d+/[^<]+)</loc>', response.text)
                        urls.extend(recipe_urls)
                        print(f"  Found {len(recipe_urls)} URLs in {sitemap_url}")
                        break
                except Exception as e:
                    print(f"  Error with {sitemap_url}: {e}")
                    continue
            
        except Exception as e:
            print(f"  Error getting sitemap: {e}")
        
        return urls

class RobustBulkRecipeScraper:
    """Robust bulk recipe scraper with multiple URL discovery methods."""
    
    def __init__(self, target_count: int = 100):
        self.target_count = target_count
        self.stats = ScrapingStats()
        self.url_finder = RobustRecipeURLFinder()
        self.existing_urls = self._get_existing_urls()
        
    def _get_existing_urls(self) -> Set[str]:
        """Get URLs of already scraped recipes."""
        existing_recipes = Recipe.objects.values_list('source_url', flat=True)
        return set(existing_recipes)
    
    def find_recipe_urls(self) -> List[str]:
        """Find recipe URLs using multiple strategies."""
        print("Finding recipe URLs using multiple strategies...")
        
        all_urls = []
        
        # Strategy 1: Known working URLs (prioritize these)
        known_urls = self.url_finder.get_known_working_urls()
        all_urls.extend(known_urls)
        print(f"Strategy 1: Added {len(known_urls)} known working URLs")
        
        # Strategy 2: Sitemap URLs
        simply_sitemap_urls = self.url_finder.get_simplyrecipes_sitemap_urls()
        allrecipes_sitemap_urls = self.url_finder.get_allrecipes_sitemap_urls()
        
        all_urls.extend(simply_sitemap_urls)
        all_urls.extend(allrecipes_sitemap_urls)
        print(f"Strategy 2: Added {len(simply_sitemap_urls)} Simply Recipes sitemap URLs")
        print(f"Strategy 2: Added {len(allrecipes_sitemap_urls)} AllRecipes sitemap URLs")
        
        # Strategy 3: Generated AllRecipes URLs (only if we need more)
        if len(all_urls) < self.target_count * 2:
            generated_urls = self.url_finder.generate_allrecipes_urls(start_id=25473, count=50)
            all_urls.extend(generated_urls)
            print(f"Strategy 3: Added {len(generated_urls)} generated AllRecipes URLs")
        
        # Remove duplicates and already scraped URLs
        unique_urls = list(set(all_urls) - self.existing_urls)
        
        # Prioritize known working URLs at the beginning
        known_working = set(self.url_finder.get_known_working_urls())
        prioritized_urls = [url for url in unique_urls if url in known_working]
        other_urls = [url for url in unique_urls if url not in known_working]
        
        final_urls = prioritized_urls + other_urls
        
        self.stats.total_urls_found = len(final_urls)
        print(f"Found {len(final_urls)} unique URLs to scrape")
        print(f"Prioritized {len(prioritized_urls)} known working URLs")
        
        return final_urls
    
    def scrape_recipes(self, urls: List[str], rate_limit_seconds: int = 2):
        """Scrape recipes with rate limiting and error handling."""
        print(f"Starting to scrape {len(urls)} recipes...")
        print(f"Rate limit: {rate_limit_seconds} seconds between requests")
        
        self.stats.start_time = datetime.now()
        
        for i, url in enumerate(urls):
            if self.stats.successful_scrapes >= self.target_count:
                print(f"Reached target of {self.target_count} recipes!")
                break
            
            try:
                print(f"[{i+1}/{len(urls)}] Scraping: {url}")
                
                # Scrape and save recipe
                recipe = format_recipe_from_url(url)
                
                self.stats.successful_scrapes += 1
                self.stats.last_success_time = datetime.now()
                
                print(f"  ✅ Success: {recipe.title}")
                
            except Exception as e:
                self.stats.failed_scrapes += 1
                print(f"  ❌ Failed: {str(e)[:100]}...")
            
            self.stats.urls_scraped += 1
            
            # Print progress every 5 recipes
            if (i + 1) % 5 == 0:
                self._print_progress()
            
            # Rate limiting
            if i < len(urls) - 1:  # Don't sleep after the last request
                time.sleep(rate_limit_seconds)
        
        self._print_final_stats()
    
    def _print_progress(self):
        """Print current progress."""
        elapsed = self.stats.elapsed_hours()
        success_rate = self.stats.success_rate()
        
        print(f"\n📊 PROGRESS UPDATE:")
        print(f"  URLs scraped: {self.stats.urls_scraped}")
        print(f"  Successful: {self.stats.successful_scrapes}")
        print(f"  Failed: {self.stats.failed_scrapes}")
        print(f"  Success rate: {success_rate:.1f}%")
        print(f"  Elapsed time: {elapsed:.1f} hours")
        print(f"  Remaining target: {self.target_count - self.stats.successful_scrapes}")
        
        if elapsed > 0 and self.stats.successful_scrapes > 0:
            rate = self.stats.successful_scrapes / elapsed
            remaining = (self.target_count - self.stats.successful_scrapes) / rate
            print(f"  Rate: {rate:.1f} recipes/hour")
            print(f"  Estimated time remaining: {remaining:.1f} hours")
        elif elapsed > 0:
            print(f"  Rate: 0.0 recipes/hour (no successful scrapes yet)")
            print(f"  Estimated time remaining: Unknown")
    
    def _print_final_stats(self):
        """Print final statistics."""
        elapsed = self.stats.elapsed_hours()
        success_rate = self.stats.success_rate()
        
        print(f"\n" + "="*60)
        print(f"SCRAPING COMPLETE")
        print(f"="*60)
        print(f"Target recipes: {self.target_count}")
        print(f"Successful scrapes: {self.stats.successful_scrapes}")
        print(f"Failed scrapes: {self.stats.failed_scrapes}")
        print(f"Success rate: {success_rate:.1f}%")
        print(f"Total time: {elapsed:.1f} hours")
        print(f"Average rate: {self.stats.successful_scrapes / elapsed:.1f} recipes/hour" if elapsed > 0 else "No time elapsed")
        
        # Save stats
        stats_data = {
            'target_count': self.target_count,
            'successful_scrapes': self.stats.successful_scrapes,
            'failed_scrapes': self.stats.failed_scrapes,
            'success_rate': success_rate,
            'elapsed_hours': elapsed,
            'start_time': self.stats.start_time.isoformat() if self.stats.start_time else None,
            'last_success_time': self.stats.last_success_time.isoformat() if self.stats.last_success_time else None
        }
        
        with open('scraping_stats.json', 'w') as f:
            json.dump(stats_data, f, indent=2)
        
        print(f"Stats saved to scraping_stats.json")

def main():
    """Main function for robust bulk scraping."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Robust bulk scrape recipes')
    parser.add_argument('--target', type=int, default=10, help='Target number of recipes to scrape')
    parser.add_argument('--rate-limit', type=int, default=2, help='Seconds between requests')
    parser.add_argument('--dry-run', action='store_true', help='Find URLs without scraping')
    
    args = parser.parse_args()
    
    print("ROBUST BULK RECIPE SCRAPER")
    print("="*60)
    print(f"Target: {args.target} recipes")
    print(f"Rate limit: {args.rate_limit} seconds")
    print(f"Dry run: {args.dry_run}")
    
    # Initialize scraper
    scraper = RobustBulkRecipeScraper(target_count=args.target)
    
    # Find URLs
    urls = scraper.find_recipe_urls()
    
    if args.dry_run:
        print(f"\nDRY RUN: Found {len(urls)} URLs to scrape")
        print("First 10 URLs:")
        for i, url in enumerate(urls[:10]):
            print(f"  {i+1}. {url}")
        return
    
    if not urls:
        print("No URLs found to scrape!")
        return
    
    # Start scraping
    scraper.scrape_recipes(urls, rate_limit_seconds=args.rate_limit)

if __name__ == "__main__":
    main() 