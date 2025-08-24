#!/usr/bin/env python3
"""
Live Migration Monitor
Continuously monitors the full-text search migration progress
"""

import os
import sys
import django
from django.db import connection
from datetime import datetime, timedelta
import time
import signal

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

class MigrationMonitor:
    def __init__(self):
        self.start_time = datetime.now()
        self.last_populated = 0
        self.running = True
        
    def signal_handler(self, signum, frame):
        print("\n\n🛑 Monitoring stopped.")
        self.running = False
        
    def estimate_completion(self, total, populated, rate_per_second):
        """Estimate completion time based on current rate"""
        if rate_per_second <= 0:
            return "Unknown"
        
        remaining = total - populated
        seconds_remaining = remaining / rate_per_second
        
        if seconds_remaining < 60:
            return f"{int(seconds_remaining)} seconds"
        elif seconds_remaining < 3600:
            return f"{int(seconds_remaining/60)} minutes"
        else:
            hours = int(seconds_remaining / 3600)
            minutes = int((seconds_remaining % 3600) / 60)
            return f"{hours}h {minutes}m"
    
    def monitor_progress(self):
        """Monitor the migration progress"""
        signal.signal(signal.SIGINT, self.signal_handler)
        
        print("🔍 Live Migration Monitor")
        print("=" * 60)
        print("Press Ctrl+C to stop monitoring\n")
        
        while self.running:
            try:
                with connection.cursor() as cursor:
                    # Check if search_vector column exists
                    cursor.execute("""
                        SELECT column_name FROM information_schema.columns 
                        WHERE table_name = 'nutrition_foodproduct' 
                        AND column_name = 'search_vector'
                    """)
                    
                    if not cursor.fetchone():
                        print("⏳ Waiting for search_vector column to be created...")
                        time.sleep(10)
                        continue
                    
                    # Get current stats
                    cursor.execute("SELECT COUNT(*) FROM nutrition_foodproduct")
                    total_records = cursor.fetchone()[0]
                    
                    cursor.execute("SELECT COUNT(*) FROM nutrition_foodproduct WHERE search_vector IS NOT NULL")
                    populated_records = cursor.fetchone()[0]
                    
                    # Calculate progress
                    progress_percent = (populated_records / total_records) * 100 if total_records > 0 else 0
                    remaining = total_records - populated_records
                    
                    # Calculate rate
                    elapsed_time = datetime.now() - self.start_time
                    elapsed_seconds = elapsed_time.total_seconds()
                    
                    if elapsed_seconds > 0:
                        rate_per_second = (populated_records - self.last_populated) / 30 if elapsed_seconds > 30 else 0
                        overall_rate = populated_records / elapsed_seconds
                    else:
                        rate_per_second = 0
                        overall_rate = 0
                    
                    # Check active queries
                    cursor.execute("""
                        SELECT COUNT(*) FROM pg_stat_activity 
                        WHERE query LIKE '%nutrition_foodproduct%' 
                        AND state = 'active'
                        AND query NOT LIKE '%pg_stat_activity%'
                    """)
                    active_queries = cursor.fetchone()[0]
                    
                    # Clear screen and show progress
                    print("\033c", end="")  # Clear screen
                    print("🔍 Live Migration Monitor")
                    print("=" * 60)
                    print(f"📊 Total records: {total_records:,}")
                    print(f"✅ Processed: {populated_records:,}")
                    print(f"📈 Progress: {progress_percent:.2f}%")
                    print(f"⏳ Remaining: {remaining:,}")
                    print(f"🕐 Elapsed: {elapsed_time}")
                    print(f"⚡ Rate: {rate_per_second:.1f} records/sec (last 30s)")
                    print(f"📊 Overall rate: {overall_rate:.1f} records/sec")
                    print(f"🔄 Active queries: {active_queries}")
                    
                    if rate_per_second > 0:
                        eta = self.estimate_completion(total_records, populated_records, overall_rate)
                        print(f"⏰ ETA: {eta}")
                    
                    # Progress bar
                    bar_length = 40
                    filled_length = int(bar_length * progress_percent / 100)
                    bar = "█" * filled_length + "-" * (bar_length - filled_length)
                    print(f"\n[{bar}] {progress_percent:.1f}%")
                    
                    if progress_percent >= 100:
                        print("\n🎉 Migration Complete!")
                        print("✅ All records processed with search vectors!")
                        break
                    
                    print(f"\n⏳ Checking again in 30 seconds...")
                    print("Press Ctrl+C to stop monitoring")
                    
                    self.last_populated = populated_records
                    
            except Exception as e:
                print(f"❌ Error monitoring: {e}")
                time.sleep(5)
                continue
            
            # Wait 30 seconds before next check
            for i in range(30):
                if not self.running:
                    break
                time.sleep(1)

if __name__ == "__main__":
    monitor = MigrationMonitor()
    monitor.monitor_progress() 