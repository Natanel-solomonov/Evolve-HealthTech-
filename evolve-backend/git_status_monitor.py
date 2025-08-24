#!/usr/bin/env python3
"""
Git Status Monitor

This script runs 'git status' every 30 seconds to monitor the repository state.
Includes progress tracking and error handling.

Usage:
    python git_status_monitor.py
"""

import subprocess
import time
import sys
import os
from datetime import datetime
from typing import Optional


class GitStatusMonitor:
    """Monitors git status every 30 seconds with progress tracking."""
    
    def __init__(self, interval: int = 30):
        self.interval = interval
        self.run_count = 0
        self.start_time = datetime.now()
        self.errors = 0
        
    def run_git_status(self) -> Optional[str]:
        """Run git status and return the output."""
        try:
            result = subprocess.run(
                ['git', 'status'],
                capture_output=True,
                text=True,
                cwd=os.getcwd(),
                timeout=10
            )
            
            if result.returncode == 0:
                return result.stdout.strip()
            else:
                return f"Error: {result.stderr.strip()}"
                
        except subprocess.TimeoutExpired:
            return "Error: Git status command timed out"
        except FileNotFoundError:
            return "Error: Git command not found"
        except Exception as e:
            return f"Error: {str(e)}"
    
    def print_progress(self):
        """Print progress information."""
        elapsed = datetime.now() - self.start_time
        elapsed_seconds = elapsed.total_seconds()
        
        print(f"\n{'='*60}")
        print(f"Git Status Monitor - Run #{self.run_count}")
        print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Elapsed: {elapsed_seconds:.1f} seconds")
        print(f"Errors: {self.errors}")
        print(f"Interval: {self.interval} seconds")
        print(f"{'='*60}")
    
    def monitor(self):
        """Main monitoring loop."""
        print("Starting Git Status Monitor...")
        print(f"Monitoring every {self.interval} seconds")
        print("Press Ctrl+C to stop")
        
        try:
            while True:
                self.run_count += 1
                self.print_progress()
                
                # Run git status
                output = self.run_git_status()
                
                if output.startswith("Error:"):
                    self.errors += 1
                    print(f"❌ {output}")
                else:
                    print("✅ Git Status:")
                    print(output)
                
                # Wait for next interval
                if self.run_count < 1:  # Don't sleep after the first run
                    time.sleep(self.interval)
                else:
                    time.sleep(self.interval)
                    
        except KeyboardInterrupt:
            print(f"\n\nMonitoring stopped by user")
            print(f"Total runs: {self.run_count}")
            print(f"Total errors: {self.errors}")
            print(f"Total time: {(datetime.now() - self.start_time).total_seconds():.1f} seconds")


def main():
    """Main entry point."""
    # Check if we're in a git repository
    if not os.path.exists('.git'):
        print("Error: Not in a git repository")
        print("Please run this script from within a git repository")
        sys.exit(1)
    
    # Create and start monitor
    monitor = GitStatusMonitor(interval=30)
    monitor.monitor()


if __name__ == "__main__":
    main() 