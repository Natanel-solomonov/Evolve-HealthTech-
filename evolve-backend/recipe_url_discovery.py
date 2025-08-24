#!/usr/bin/env python3
import sys
import os
import django
import requests
import time
import random
import re
from urllib.parse import urljoin, urlparse
from typing import List, Set
import logging

# Setup Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class RecipeURLDiscovery:
    """Discover all recipe URLs from AllRecipes and Simply Recipes."""
    
    USER_AGENTS = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/117.0',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    ]
    
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': random.choice(self.USER_AGENTS),
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        })
    
    def random_delay(self, min_seconds=1, max_seconds=3):
        """Add random delay to avoid detection."""
        delay = random.uniform(min_seconds, max_seconds)
        time.sleep(delay)
    
    def get_with_retry(self, url: str, max_retries=3) -> requests.Response:
        """Get URL with retry logic and rotating user agents."""
        for attempt in range(max_retries):
            try:
                # Rotate user agent
                self.session.headers['User-Agent'] = random.choice(self.USER_AGENTS)
                
                response = self.session.get(url, timeout=30)
                
                if response.status_code == 200:
                    return response
                elif response.status_code == 429:
                    wait_time = (2 ** attempt) * 5  # Exponential backoff
                    logger.warning(f"Rate limited, waiting {wait_time}s...")
                    time.sleep(wait_time)
                else:
                    logger.warning(f"HTTP {response.status_code} for {url}")
                    
            except Exception as e:
                logger.error(f"Attempt {attempt + 1} failed for {url}: {e}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)
        
        return None
    
    def discover_allrecipes_urls(self) -> Set[str]:
        """Discover AllRecipes URLs using multiple strategies."""
        logger.info("Discovering AllRecipes URLs...")
        urls = set()
        
        # Strategy 1: Recursive sitemap crawling
        try:
            main_sitemap = "https://www.allrecipes.com/sitemap.xml"
            response = self.get_with_retry(main_sitemap)
            if response:
                from bs4 import BeautifulSoup
                soup = BeautifulSoup(response.content, 'xml')
                
                # Find all sitemap URLs
                sitemap_urls = []
                for loc in soup.find_all('loc'):
                    sitemap_url = loc.text.strip()
                    if sitemap_url.endswith('.xml'):
                        sitemap_urls.append(sitemap_url)
                
                logger.info(f"Found {len(sitemap_urls)} sitemaps to crawl")
                
                # Crawl each sitemap
                for sitemap_url in sitemap_urls:
                    self.random_delay()
                    logger.info(f"Crawling sitemap: {sitemap_url}")
                    
                    sitemap_response = self.get_with_retry(sitemap_url)
                    if sitemap_response:
                        sitemap_soup = BeautifulSoup(sitemap_response.content, 'xml')
                        
                        # Extract recipe URLs
                        for loc in sitemap_soup.find_all('loc'):
                            url = loc.text.strip()
                            if '/recipe/' in url and url.startswith('https://www.allrecipes.com'):
                                urls.add(url)
                        
                        logger.info(f"Sitemap {sitemap_url}: Found {len(urls)} total URLs so far")
                        
        except Exception as e:
            logger.error(f"Error parsing sitemaps: {e}")
        
        # Strategy 2: Category pages with pagination
        categories = [
            'https://www.allrecipes.com/recipes/',
            'https://www.allrecipes.com/recipes/76/appetizers-and-snacks/',
            'https://www.allrecipes.com/recipes/156/bread/',
            'https://www.allrecipes.com/recipes/78/breakfast-and-brunch/',
            'https://www.allrecipes.com/recipes/79/desserts/',
            'https://www.allrecipes.com/recipes/17561/lunch/',
            'https://www.allrecipes.com/recipes/17562/dinner/',
            'https://www.allrecipes.com/recipes/17563/side-dish/',
            'https://www.allrecipes.com/recipes/17564/salad/',
            'https://www.allrecipes.com/recipes/17565/soup/',
            'https://www.allrecipes.com/recipes/17566/pasta/',
            'https://www.allrecipes.com/recipes/17567/meat-and-poultry/',
            'https://www.allrecipes.com/recipes/17568/seafood/',
            'https://www.allrecipes.com/recipes/17569/vegetarian/',
        ]
        
        for category_url in categories:
            try:
                self.random_delay()
                logger.info(f"Processing category: {category_url}")
                
                # Get first page
                response = self.get_with_retry(category_url)
                if response:
                    from bs4 import BeautifulSoup
                    soup = BeautifulSoup(response.content, 'html.parser')
                    
                    # Find recipe links on this page
                    recipe_links = soup.find_all('a', href=re.compile(r'/recipe/\d+/'))
                    for link in recipe_links:
                        href = link.get('href')
                        if href and href.startswith('/'):
                            full_url = urljoin('https://www.allrecipes.com', href)
                            urls.add(full_url)
                    
                    # Look for pagination and crawl additional pages
                    pagination_links = soup.find_all('a', href=re.compile(r'page=\d+'))
                    page_urls = set()
                    
                    for link in pagination_links:
                        href = link.get('href')
                        if href and 'page=' in href:
                            if href.startswith('/'):
                                full_url = urljoin('https://www.allrecipes.com', href)
                            else:
                                full_url = href
                            page_urls.add(full_url)
                    
                    # Crawl pagination pages (limit to first 10 pages per category)
                    for page_url in list(page_urls)[:10]:
                        self.random_delay()
                        page_response = self.get_with_retry(page_url)
                        if page_response:
                            page_soup = BeautifulSoup(page_response.content, 'html.parser')
                            page_recipe_links = page_soup.find_all('a', href=re.compile(r'/recipe/\d+/'))
                            
                            for link in page_recipe_links:
                                href = link.get('href')
                                if href and href.startswith('/'):
                                    full_url = urljoin('https://www.allrecipes.com', href)
                                    urls.add(full_url)
                
                logger.info(f"Category {category_url}: Found {len(urls)} total URLs so far")
                
            except Exception as e:
                logger.error(f"Error processing category {category_url}: {e}")
        
        # Strategy 3: Search result pages
        search_terms = ['chicken', 'pasta', 'salad', 'soup', 'dessert', 'breakfast']
        for term in search_terms:
            try:
                search_url = f"https://www.allrecipes.com/search?q={term}"
                self.random_delay()
                
                response = self.get_with_retry(search_url)
                if response:
                    from bs4 import BeautifulSoup
                    soup = BeautifulSoup(response.content, 'html.parser')
                    
                    recipe_links = soup.find_all('a', href=re.compile(r'/recipe/\d+/'))
                    for link in recipe_links:
                        href = link.get('href')
                        if href and href.startswith('/'):
                            full_url = urljoin('https://www.allrecipes.com', href)
                            urls.add(full_url)
                    
                    logger.info(f"Search '{term}': Found {len(urls)} total URLs so far")
                    
            except Exception as e:
                logger.error(f"Error processing search term '{term}': {e}")
        
        return urls
    
    def discover_simplyrecipes_urls(self) -> Set[str]:
        """Discover Simply Recipes URLs using multiple strategies."""
        logger.info("Discovering Simply Recipes URLs...")
        urls = set()
        
        # Strategy 1: Recursive sitemap crawling
        try:
            main_sitemap = "https://www.simplyrecipes.com/sitemap.xml"
            response = self.get_with_retry(main_sitemap)
            if response:
                from bs4 import BeautifulSoup
                soup = BeautifulSoup(response.content, 'xml')
                
                # Find all sitemap URLs
                sitemap_urls = []
                for loc in soup.find_all('loc'):
                    sitemap_url = loc.text.strip()
                    if sitemap_url.endswith('.xml'):
                        sitemap_urls.append(sitemap_url)
                
                logger.info(f"Found {len(sitemap_urls)} sitemaps to crawl")
                
                # Crawl each sitemap
                for sitemap_url in sitemap_urls:
                    self.random_delay()
                    logger.info(f"Crawling sitemap: {sitemap_url}")
                    
                    sitemap_response = self.get_with_retry(sitemap_url)
                    if sitemap_response:
                        sitemap_soup = BeautifulSoup(sitemap_response.content, 'xml')
                        
                        # Extract recipe URLs
                        for loc in sitemap_soup.find_all('loc'):
                            url = loc.text.strip()
                            if '/recipes/' in url and url.startswith('https://www.simplyrecipes.com'):
                                urls.add(url)
                        
                        logger.info(f"Sitemap {sitemap_url}: Found {len(urls)} total URLs so far")
                        
        except Exception as e:
            logger.error(f"Error parsing sitemaps: {e}")
        
        # Strategy 2: Category pages with pagination
        categories = [
            'https://www.simplyrecipes.com/recipes/',
            'https://www.simplyrecipes.com/recipes/breakfast/',
            'https://www.simplyrecipes.com/recipes/lunch/',
            'https://www.simplyrecipes.com/recipes/dinner/',
            'https://www.simplyrecipes.com/recipes/dessert/',
            'https://www.simplyrecipes.com/recipes/appetizer/',
            'https://www.simplyrecipes.com/recipes/soup/',
            'https://www.simplyrecipes.com/recipes/salad/',
            'https://www.simplyrecipes.com/recipes/pasta/',
            'https://www.simplyrecipes.com/recipes/meat/',
            'https://www.simplyrecipes.com/recipes/seafood/',
            'https://www.simplyrecipes.com/recipes/vegetarian/',
            'https://www.simplyrecipes.com/recipes/bread/',
        ]
        
        for category_url in categories:
            try:
                self.random_delay()
                logger.info(f"Processing category: {category_url}")
                
                # Get first page
                response = self.get_with_retry(category_url)
                if response:
                    from bs4 import BeautifulSoup
                    soup = BeautifulSoup(response.content, 'html.parser')
                    
                    # Find recipe links on this page
                    recipe_links = soup.find_all('a', href=re.compile(r'/recipes/'))
                    for link in recipe_links:
                        href = link.get('href')
                        if href and href.startswith('/') and '/recipes/' in href:
                            full_url = urljoin('https://www.simplyrecipes.com', href)
                            urls.add(full_url)
                    
                    # Look for pagination and crawl additional pages
                    pagination_links = soup.find_all('a', href=re.compile(r'page=\d+'))
                    page_urls = set()
                    
                    for link in pagination_links:
                        href = link.get('href')
                        if href and 'page=' in href:
                            if href.startswith('/'):
                                full_url = urljoin('https://www.simplyrecipes.com', href)
                            else:
                                full_url = href
                            page_urls.add(full_url)
                    
                    # Crawl pagination pages (limit to first 10 pages per category)
                    for page_url in list(page_urls)[:10]:
                        self.random_delay()
                        page_response = self.get_with_retry(page_url)
                        if page_response:
                            page_soup = BeautifulSoup(page_response.content, 'html.parser')
                            page_recipe_links = page_soup.find_all('a', href=re.compile(r'/recipes/'))
                            
                            for link in page_recipe_links:
                                href = link.get('href')
                                if href and href.startswith('/') and '/recipes/' in href:
                                    full_url = urljoin('https://www.simplyrecipes.com', href)
                                    urls.add(full_url)
                
                logger.info(f"Category {category_url}: Found {len(urls)} total URLs so far")
                
            except Exception as e:
                logger.error(f"Error processing category {category_url}: {e}")
        
        # Strategy 3: Search result pages
        search_terms = ['chicken', 'pasta', 'salad', 'soup', 'dessert', 'breakfast']
        for term in search_terms:
            try:
                search_url = f"https://www.simplyrecipes.com/search?q={term}"
                self.random_delay()
                
                response = self.get_with_retry(search_url)
                if response:
                    from bs4 import BeautifulSoup
                    soup = BeautifulSoup(response.content, 'html.parser')
                    
                    recipe_links = soup.find_all('a', href=re.compile(r'/recipes/'))
                    for link in recipe_links:
                        href = link.get('href')
                        if href and href.startswith('/') and '/recipes/' in href:
                            full_url = urljoin('https://www.simplyrecipes.com', href)
                            urls.add(full_url)
                    
                    logger.info(f"Search '{term}': Found {len(urls)} total URLs so far")
                    
            except Exception as e:
                logger.error(f"Error processing search term '{term}': {e}")
        
        return urls
    
    def save_urls_to_file(self, urls: Set[str], filename: str):
        """Save URLs to a text file."""
        with open(filename, 'w') as f:
            for url in sorted(urls):
                f.write(url + '\n')
        logger.info(f"Saved {len(urls)} URLs to {filename}")
    
    def discover_all_urls(self):
        """Discover URLs from both sites and save to files."""
        logger.info("Starting URL discovery for both sites...")
        
        # Discover AllRecipes URLs
        allrecipes_urls = self.discover_allrecipes_urls()
        self.save_urls_to_file(allrecipes_urls, 'allrecipes_urls.txt')
        
        # Discover Simply Recipes URLs
        simply_urls = self.discover_simplyrecipes_urls()
        self.save_urls_to_file(simply_urls, 'simplyrecipes_urls.txt')
        
        # Combined file
        all_urls = allrecipes_urls.union(simply_urls)
        self.save_urls_to_file(all_urls, 'all_recipe_urls.txt')
        
        logger.info(f"Discovery complete!")
        logger.info(f"AllRecipes: {len(allrecipes_urls)} URLs")
        logger.info(f"Simply Recipes: {len(simply_urls)} URLs")
        logger.info(f"Total: {len(all_urls)} URLs")

if __name__ == "__main__":
    discovery = RecipeURLDiscovery()
    discovery.discover_all_urls() 