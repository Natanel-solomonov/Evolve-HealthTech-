#!/usr/bin/env python3
import sys
import os
import django
import time
import random
import json
from typing import List, Dict
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

class BulkRecipeScraper:
    """Bulk scrape recipes from URLs stored in text files."""
    
    def __init__(self, rate_limit_seconds=2):
        self.rate_limit_seconds = rate_limit_seconds
        self.stats = {
            'total_processed': 0,
            'successful': 0,
            'failed': 0,
            'start_time': datetime.now(),
            'errors': []
        }
    
    def load_urls_from_file(self, filename: str) -> List[str]:
        """Load URLs from a text file."""
        try:
            with open(filename, 'r') as f:
                urls = [line.strip() for line in f if line.strip()]
            logger.info(f"Loaded {len(urls)} URLs from {filename}")
            return urls
        except FileNotFoundError:
            logger.error(f"File {filename} not found!")
            return []
    
    def random_delay(self, min_seconds=None, max_seconds=None):
        """Add random delay to avoid detection."""
        if min_seconds is None:
            min_seconds = self.rate_limit_seconds
        if max_seconds is None:
            max_seconds = min_seconds + 2
        
        delay = random.uniform(min_seconds, max_seconds)
        time.sleep(delay)
    
    def scrape_url(self, url: str) -> Dict:
        """Scrape a single URL and return results."""
        try:
            logger.info(f"Scraping: {url}")
            
            # Use the existing formatter which handles scraping and saving
            recipe = format_recipe_from_url(url)
            
            if recipe:
                self.stats['successful'] += 1
                logger.info(f"✅ Success: {recipe.title}")
                return {
                    'url': url,
                    'status': 'success',
                    'recipe_id': recipe.id,
                    'title': recipe.title
                }
            else:
                self.stats['failed'] += 1
                error_msg = f"Failed to scrape {url}"
                self.stats['errors'].append(error_msg)
                logger.error(f"❌ {error_msg}")
                return {
                    'url': url,
                    'status': 'failed',
                    'error': 'No recipe data extracted'
                }
                
        except Exception as e:
            self.stats['failed'] += 1
            error_msg = f"Error scraping {url}: {str(e)}"
            self.stats['errors'].append(error_msg)
            logger.error(f"❌ {error_msg}")
            return {
                'url': url,
                'status': 'error',
                'error': str(e)
            }
    
    def print_progress(self):
        """Print current progress."""
        elapsed = (datetime.now() - self.stats['start_time']).total_seconds() / 3600  # hours
        
        print(f"\n{'='*60}")
        print(f"PROGRESS UPDATE")
        print(f"{'='*60}")
        print(f"Total processed: {self.stats['total_processed']}")
        print(f"Successful: {self.stats['successful']}")
        print(f"Failed: {self.stats['failed']}")
        print(f"Success rate: {(self.stats['successful'] / max(1, self.stats['total_processed'])) * 100:.1f}%")
        
        if elapsed > 0:
            rate = self.stats['successful'] / elapsed
            print(f"Rate: {rate:.1f} recipes/hour")
        
        if self.stats['errors']:
            print(f"\nRecent errors:")
            for error in self.stats['errors'][-5:]:  # Last 5 errors
                print(f"  - {error}")
        print(f"{'='*60}\n")
    
    def scrape_from_file(self, filename: str, max_urls=None, save_results=True):
        """Scrape recipes from URLs in a file."""
        urls = self.load_urls_from_file(filename)
        
        if not urls:
            logger.error("No URLs to process!")
            return
        
        if max_urls:
            urls = urls[:max_urls]
            logger.info(f"Limiting to {max_urls} URLs")
        
        results = []
        
        for i, url in enumerate(urls, 1):
            self.stats['total_processed'] += 1
            
            # Scrape the URL
            result = self.scrape_url(url)
            results.append(result)
            
            # Add delay between requests
            if i < len(urls):  # Don't delay after the last URL
                self.random_delay()
            
            # Print progress every 10 URLs
            if i % 10 == 0:
                self.print_progress()
                
                # Save intermediate results
                if save_results:
                    self.save_results(results, f"scraping_results_{i}.json")
        
        # Final progress report
        self.print_progress()
        
        # Save final results
        if save_results:
            self.save_results(results, "final_scraping_results.json")
        
        return results
    
    def save_results(self, results: List[Dict], filename: str):
        """Save scraping results to JSON file."""
        with open(filename, 'w') as f:
            json.dump({
                'stats': self.stats,
                'results': results
            }, f, indent=2, default=str)
        logger.info(f"Results saved to {filename}")

def main():
    """Main function to run bulk scraping."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Bulk scrape recipes from URLs in files')
    parser.add_argument('--file', '-f', default='all_recipe_urls.txt', 
                       help='File containing URLs (default: all_recipe_urls.txt)')
    parser.add_argument('--max', '-m', type=int, 
                       help='Maximum number of URLs to process')
    parser.add_argument('--rate-limit', '-r', type=float, default=2.0,
                       help='Rate limit in seconds between requests (default: 2.0)')
    parser.add_argument('--no-save', action='store_true',
                       help='Don\'t save results to files')
    
    args = parser.parse_args()
    
    # Check if URL file exists
    if not os.path.exists(args.file):
        print(f"❌ URL file '{args.file}' not found!")
        print("Please run recipe_url_discovery.py first to generate URL files.")
        return
    
    # Create scraper and run
    scraper = BulkRecipeScraper(rate_limit_seconds=args.rate_limit)
    
    print(f"🚀 Starting bulk scraping from {args.file}")
    print(f"Rate limit: {args.rate_limit}s between requests")
    if args.max:
        print(f"Max URLs: {args.max}")
    print(f"Save results: {not args.no_save}")
    print("="*60)
    
    try:
        results = scraper.scrape_from_file(
            args.file, 
            max_urls=args.max, 
            save_results=not args.no_save
        )
        
        print(f"\n🎉 Bulk scraping complete!")
        print(f"Total processed: {scraper.stats['total_processed']}")
        print(f"Successful: {scraper.stats['successful']}")
        print(f"Failed: {scraper.stats['failed']}")
        
    except KeyboardInterrupt:
        print(f"\n⚠️  Scraping interrupted by user")
        print(f"Processed {scraper.stats['total_processed']} URLs before stopping")
    except Exception as e:
        print(f"\n❌ Error during bulk scraping: {e}")
        logger.exception("Bulk scraping error")

if __name__ == "__main__":
    main() 