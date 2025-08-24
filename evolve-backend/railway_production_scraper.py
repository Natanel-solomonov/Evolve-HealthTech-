#!/usr/bin/env python3
import sys
import os
import django
import requests
import time
import random
import json
import signal
from typing import List, Dict, Tuple
import logging
from datetime import datetime
from urllib.parse import urlparse
import re

# Setup Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from recipes.services.recipe_formatter import format_recipe_from_url
from recipes.models import Recipe

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class RailwayProductionScraper:
    """Production scraper that pushes data directly to Railway PostgreSQL database."""
    
    USER_AGENTS = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/117.0',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
    ]
    
    def __init__(self, target_recipe_count: int, rate_limit_seconds: float = 2.0):
        self.target_count = target_recipe_count
        self.rate_limit_seconds = rate_limit_seconds
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': random.choice(self.USER_AGENTS),
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
        })
        
        self.stats = {
            'total_processed': 0,
            'successful': 0,
            'failed': 0,
            'start_time': datetime.now(),
            'errors': [],
            'last_successful_url': None,
            'railway_connection_tested': False
        }
        
        # Test Railway connection
        self.test_railway_connection()
        
        # Load existing progress
        self.load_progress()
        
        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)
    
    def test_railway_connection(self):
        """Test connection to Railway database."""
        try:
            from django.db import connection
            with connection.cursor() as cursor:
                cursor.execute("SELECT COUNT(*) FROM recipes_recipe")
                count = cursor.fetchone()[0]
                logger.info(f"✅ Railway connection successful! Current recipe count: {count}")
                self.stats['railway_connection_tested'] = True
        except Exception as e:
            logger.error(f"❌ Railway connection failed: {e}")
            logger.error("Make sure your DATABASE_URL is set correctly in your .env file")
            sys.exit(1)
    
    def signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully."""
        logger.info(f"Received signal {signum}, saving progress and shutting down...")
        self.save_progress()
        sys.exit(0)
    
    def load_progress(self):
        """Load progress from file if it exists."""
        try:
            if os.path.exists('railway_scraping_progress.json'):
                with open('railway_scraping_progress.json', 'r') as f:
                    progress = json.load(f)
                    self.stats.update(progress)
                    logger.info(f"Loaded progress: {self.stats['successful']} recipes already scraped to Railway")
        except Exception as e:
            logger.warning(f"Could not load progress: {e}")
    
    def save_progress(self):
        """Save current progress to file."""
        try:
            with open('railway_scraping_progress.json', 'w') as f:
                json.dump(self.stats, f, indent=2, default=str)
            logger.info(f"Progress saved: {self.stats['successful']} recipes completed on Railway")
        except Exception as e:
            logger.error(f"Could not save progress: {e}")
    
    def random_delay(self):
        """Add random delay to avoid detection."""
        delay = random.uniform(self.rate_limit_seconds, self.rate_limit_seconds + 2)
        time.sleep(delay)
    
    def get_traffic_indicators(self, url: str) -> Dict:
        """Get traffic indicators for a recipe URL with timeout."""
        try:
            # Rotate user agent
            self.session.headers['User-Agent'] = random.choice(self.USER_AGENTS)
            
            # Shorter timeout for traffic analysis
            response = self.session.get(url, timeout=15)
            if response.status_code != 200:
                return {'score': 0, 'indicators': {}}
            
            from bs4 import BeautifulSoup
            soup = BeautifulSoup(response.content, 'html.parser')
            
            indicators = {}
            
            # Simplified traffic indicators (faster)
            # 1. Recipe rating
            rating_match = re.search(r'ratingValue["\']:\s*([\d.]+)', response.text)
            rating = float(rating_match.group(1)) if rating_match else 0
            indicators['rating'] = rating
            
            # 2. Review count
            review_match = re.search(r'reviewCount["\']:\s*(\d+)', response.text)
            review_count = int(review_match.group(1)) if review_match else 0
            indicators['review_count'] = review_count
            
            # 3. Recipe age (simplified)
            date_match = re.search(r'datePublished["\']:\s*["\']([^"\']+)["\']', response.text)
            if date_match:
                try:
                    from datetime import datetime
                    date_str = date_match.group(1)
                    pub_date = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
                    days_old = (datetime.now() - pub_date).days
                    indicators['days_old'] = days_old
                except:
                    indicators['days_old'] = 365
            
            # Calculate simple traffic score
            score = self.calculate_simple_traffic_score(indicators)
            
            return {
                'score': score,
                'indicators': indicators
            }
            
        except Exception as e:
            logger.error(f"Error getting traffic indicators for {url}: {e}")
            return {'score': 0, 'indicators': {}}
    
    def calculate_simple_traffic_score(self, indicators: Dict) -> float:
        """Calculate simplified traffic score."""
        score = 0
        
        # Rating weight (50%)
        rating_score = indicators.get('rating', 0) / 5.0
        score += rating_score * 0.5
        
        # Review count weight (30%)
        review_score = min(indicators.get('review_count', 0) / 1000, 10)
        score += review_score * 0.3
        
        # Recipe age weight (20%) - newer is better
        days_old = indicators.get('days_old', 365)
        age_score = max(0, 1 - (days_old / 365))
        score += age_score * 0.2
        
        return score
    
    def rank_urls_by_traffic(self, urls: List[str], sample_size: int = 50) -> List[Tuple[str, float]]:
        """Rank URLs by traffic score with smaller sample."""
        logger.info(f"Ranking {len(urls)} URLs by traffic (sampling {sample_size})...")
        
        # Smaller sample for faster ranking
        sample_urls = urls[:sample_size] if len(urls) > sample_size else urls
        
        ranked_urls = []
        
        for i, url in enumerate(sample_urls):
            logger.info(f"Analyzing traffic for URL {i+1}/{len(sample_urls)}: {url}")
            
            traffic_data = self.get_traffic_indicators(url)
            ranked_urls.append((url, traffic_data['score']))
            
            # Add delay between requests
            if i < len(sample_urls) - 1:
                self.random_delay()
        
        # Sort by score (highest first)
        ranked_urls.sort(key=lambda x: x[1], reverse=True)
        
        logger.info(f"Ranked {len(ranked_urls)} URLs by traffic")
        
        # Return ranked URLs + remaining unranked URLs
        remaining_urls = urls[len(sample_urls):]
        return ranked_urls + [(url, 0) for url in remaining_urls]
    
    def scrape_until_target(self, urls: List[str], max_urls_to_try: int = None) -> Dict:
        """Scrape recipes until target count is reached with Railway database."""
        logger.info(f"Starting Railway production scraping until {self.target_count} recipes...")
        
        # Skip already processed URLs
        processed_urls = set()
        if self.stats.get('last_successful_url'):
            # Find the index of the last successful URL
            try:
                last_index = urls.index(self.stats['last_successful_url'])
                processed_urls = set(urls[:last_index + 1])
                logger.info(f"Skipping {len(processed_urls)} already processed URLs")
            except ValueError:
                pass
        
        # Rank URLs by traffic
        ranked_urls = self.rank_urls_by_traffic(urls)
        
        # Filter out already processed URLs
        ranked_urls = [(url, score) for url, score in ranked_urls if url not in processed_urls]
        
        # Limit URLs to try if specified
        if max_urls_to_try:
            ranked_urls = ranked_urls[:max_urls_to_try]
        
        results = []
        
        for i, (url, traffic_score) in enumerate(ranked_urls):
            if self.stats['successful'] >= self.target_count:
                logger.info(f"🎯 Target of {self.target_count} recipes reached on Railway!")
                break
            
            self.stats['total_processed'] += 1
            
            try:
                logger.info(f"Scraping [{i+1}/{len(ranked_urls)}] (Score: {traffic_score:.2f}): {url}")
                
                # Scrape the recipe with timeout
                recipe = format_recipe_from_url(url)
                
                if recipe:
                    self.stats['successful'] += 1
                    self.stats['last_successful_url'] = url
                    logger.info(f"✅ Success: {recipe.title} (Railway ID: {recipe.id})")
                    
                    results.append({
                        'url': url,
                        'traffic_score': traffic_score,
                        'status': 'success',
                        'recipe_id': recipe.id,
                        'title': recipe.title
                    })
                else:
                    self.stats['failed'] += 1
                    error_msg = f"Failed to scrape {url}"
                    self.stats['errors'].append(error_msg)
                    logger.error(f"❌ {error_msg}")
                    
                    results.append({
                        'url': url,
                        'traffic_score': traffic_score,
                        'status': 'failed',
                        'error': 'No recipe data extracted'
                    })
                    
            except Exception as e:
                self.stats['failed'] += 1
                error_msg = f"Error scraping {url}: {str(e)}"
                self.stats['errors'].append(error_msg)
                logger.error(f"❌ {error_msg}")
                
                results.append({
                    'url': url,
                    'traffic_score': traffic_score,
                    'status': 'error',
                    'error': str(e)
                })
            
            # Add delay between requests
            if i < len(ranked_urls) - 1:
                self.random_delay()
            
            # Save progress every 5 recipes
            if (i + 1) % 5 == 0:
                self.save_progress()
                self.print_progress()
        
        # Final progress report
        self.print_progress()
        self.save_progress()
        
        return {
            'results': results,
            'stats': self.stats,
            'target_reached': self.stats['successful'] >= self.target_count,
            'urls_processed': len(results)
        }
    
    def print_progress(self):
        """Print current progress."""
        elapsed = (datetime.now() - self.stats['start_time']).total_seconds() / 3600  # hours
        
        print(f"\n{'='*60}")
        print(f"RAILWAY PRODUCTION SCRAPING PROGRESS")
        print(f"{'='*60}")
        print(f"Target recipes: {self.target_count}")
        print(f"Total processed: {self.stats['total_processed']}")
        print(f"Successful: {self.stats['successful']}")
        print(f"Failed: {self.stats['failed']}")
        print(f"Success rate: {(self.stats['successful'] / max(1, self.stats['total_processed'])) * 100:.1f}%")
        print(f"Remaining target: {max(0, self.target_count - self.stats['successful'])}")
        
        if elapsed > 0:
            rate = self.stats['successful'] / elapsed
            remaining = (self.target_count - self.stats['successful']) / rate if rate > 0 else 0
            print(f"Rate: {rate:.1f} recipes/hour")
            print(f"Estimated time remaining: {remaining:.1f} hours")
        
        if self.stats['errors']:
            print(f"\nRecent errors:")
            for error in self.stats['errors'][-3:]:  # Last 3 errors
                print(f"  - {error}")
        print(f"{'='*60}\n")

def main():
    """Main function for Railway production scraping."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Railway production recipe scraping')
    parser.add_argument('--target', '-t', type=int, required=True,
                       help='Target number of recipes to scrape')
    parser.add_argument('--file', '-f', default='all_recipe_urls.txt',
                       help='File containing URLs (default: all_recipe_urls.txt)')
    parser.add_argument('--rate-limit', '-r', type=float, default=2.0,
                       help='Rate limit in seconds between requests (default: 2.0)')
    parser.add_argument('--max-urls', '-m', type=int,
                       help='Maximum URLs to try (default: all)')
    parser.add_argument('--sample-size', '-s', type=int, default=50,
                       help='Number of URLs to sample for traffic ranking (default: 50)')
    
    args = parser.parse_args()
    
    # Check if URL file exists
    if not os.path.exists(args.file):
        print(f"❌ URL file '{args.file}' not found!")
        print("Please run recipe_url_discovery.py first to generate URL files.")
        return
    
    # Load URLs
    with open(args.file, 'r') as f:
        urls = [line.strip() for line in f if line.strip()]
    
    print(f"🚀 Starting Railway production scraping")
    print(f"Target recipes: {args.target}")
    print(f"URLs available: {len(urls)}")
    print(f"Rate limit: {args.rate_limit}s between requests")
    print(f"Sample size for ranking: {args.sample_size}")
    if args.max_urls:
        print(f"Max URLs to try: {args.max_urls}")
    print("="*60)
    
    # Create scraper and run
    scraper = RailwayProductionScraper(
        target_recipe_count=args.target,
        rate_limit_seconds=args.rate_limit
    )
    
    try:
        results = scraper.scrape_until_target(urls, max_urls_to_try=args.max_urls)
        
        print(f"\n🎉 Railway production scraping complete!")
        print(f"Target reached: {results['target_reached']}")
        print(f"URLs processed: {results['urls_processed']}")
        print(f"Final stats: {results['stats']}")
        
        # Save results
        with open('railway_production_results.json', 'w') as f:
            json.dump(results, f, indent=2, default=str)
        print(f"Results saved to railway_production_results.json")
        
    except KeyboardInterrupt:
        print(f"\n⚠️  Scraping interrupted by user")
        print(f"Processed {scraper.stats['total_processed']} URLs before stopping")
        scraper.save_progress()
    except Exception as e:
        print(f"\n❌ Error during Railway production scraping: {e}")
        logger.exception("Railway production scraping error")
        scraper.save_progress()

if __name__ == "__main__":
    main() 