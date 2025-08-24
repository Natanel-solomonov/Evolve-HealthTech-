#!/bin/bash

# =============================================================================
# Environment Cleanup and Update Script for Evolve Backend
# =============================================================================
# This script ensures the development environment is up to date and cleaned up
# Handles Python dependencies, system packages, Django cache, and more
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Global variables for commands
PYTHON_CMD=""
PIP_CMD=""

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Progress tracking
TOTAL_STEPS=8
CURRENT_STEP=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "${BLUE}[Step $CURRENT_STEP/$TOTAL_STEPS]${NC} $1"
}

# Error handling
cleanup_on_error() {
    log_error "Script failed at step $CURRENT_STEP. Cleaning up..."
    exit 1
}

trap cleanup_on_error ERR

# Check prerequisites
check_prerequisites() {
    progress "Checking prerequisites..."
    
    # Check if we're in the right directory
    if [[ ! -f "manage.py" ]]; then
        log_error "manage.py not found. Please run this script from the Django project root."
        exit 1
    fi
    
    # Check if we're in a virtual environment
    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
        log_info "Virtual environment detected: $(basename "$VIRTUAL_ENV")"
    else
        log_warning "No virtual environment detected. Consider using a virtual environment for Python development."
    fi
    
    # Determine which Python command to use
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        log_error "Python is not installed or not in PATH"
        exit 1
    fi
    
    # Determine which pip command to use
    if command -v pip3 &> /dev/null; then
        PIP_CMD="pip3"
    elif command -v pip &> /dev/null; then
        PIP_CMD="pip"
    else
        log_error "pip is not installed or not in PATH"
        exit 1
    fi
    
    # Check if requirements.txt exists
    if [[ ! -f "requirements.txt" ]]; then
        log_warning "requirements.txt not found. Skipping Python dependency updates."
    fi
    
    # Check Python installation type
    if $PIP_CMD show pip 2>/dev/null | grep -q "Location.*Library/Python"; then
        log_info "Detected user-level Python installation (--user installs)"
    elif $PIP_CMD show pip 2>/dev/null | grep -q "Location.*site-packages"; then
        log_info "Detected system-level Python installation"
    fi
    
    log_info "Using Python: $PYTHON_CMD"
    log_info "Using pip: $PIP_CMD"
    log_success "Prerequisites check passed"
}

# Clean Django cache and temporary files
clean_django_cache() {
    progress "Cleaning Django cache and temporary files..."
    
    # Remove Python cache files
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -delete 2>/dev/null || true
    find . -name "*.pyo" -delete 2>/dev/null || true
    
    # Remove Django cache
    if [[ -d "cache" ]]; then
        rm -rf cache/
        log_info "Removed Django cache directory"
    fi
    
    # Clean Django sessions (if using file-based sessions)
    if [[ -d "django_sessions" ]]; then
        rm -rf django_sessions/
        log_info "Removed Django sessions directory"
    fi
    
    # Remove media files cache (if any)
    if [[ -d "media/cache" ]]; then
        rm -rf media/cache/
        log_info "Removed media cache"
    fi
    
    log_success "Django cache and temporary files cleaned"
}

# Update Python dependencies
update_python_dependencies() {
    progress "Updating Python dependencies..."
    
    if [[ -f "requirements.txt" ]]; then
        log_info "Installing/updating requirements.txt dependencies..."
        $PIP_CMD install -r requirements.txt --upgrade
        
        log_info "Installing pip-review for dependency management..."
        $PIP_CMD install pip-review --upgrade || {
            log_warning "Could not install pip-review. Skipping outdated package check."
            log_success "Python dependencies updated (basic)"
            return
        }
        
        log_info "Checking for outdated packages..."
        $PYTHON_CMD -m pip_review --auto || {
            log_warning "Some packages couldn't be auto-updated. Run 'pip-review' manually to review."
        }
        
        log_success "Python dependencies updated"
    else
        log_warning "requirements.txt not found. Skipping Python dependency updates."
    fi
}

# Fix common Homebrew tap issues
fix_homebrew_taps() {
    log_info "Checking for problematic Homebrew taps..."
    
    # Remove deprecated/non-existent taps
    local deprecated_taps=(
        "homebrew/homebrew-cask-versions"
        "homebrew/cask-versions"
    )
    
    for tap in "${deprecated_taps[@]}"; do
        if brew tap | grep -q "$tap" 2>/dev/null; then
            log_info "Removing deprecated tap: $tap"
            brew untap "$tap" 2>/dev/null || true
        fi
    done
}

# Update system packages (macOS with Homebrew)
update_system_packages() {
    progress "Updating system packages..."
    
    if command -v brew &> /dev/null; then
        fix_homebrew_taps
        
        log_info "Updating Homebrew..."
        brew update || {
            log_warning "Homebrew update had issues, but continuing..."
        }
        
        log_info "Upgrading Homebrew packages..."
        brew upgrade || {
            log_warning "Some Homebrew packages couldn't be upgraded"
        }
        
        log_info "Cleaning up Homebrew..."
        brew cleanup --prune=all || {
            log_warning "Homebrew cleanup had issues"
        }
        
        log_info "Running Homebrew doctor..."
        brew doctor || {
            log_warning "Homebrew doctor found issues. Please review the output above."
        }
        
        log_success "System packages updated via Homebrew"
    else
        log_warning "Homebrew not found. Skipping system package updates."
    fi
}

# Clean pip cache
clean_pip_cache() {
    progress "Cleaning pip cache..."
    
    $PIP_CMD cache purge 2>/dev/null || {
        log_warning "Could not purge pip cache (older pip version?)"
    }
    
    log_success "Pip cache cleaned"
}

# Django-specific maintenance
django_maintenance() {
    progress "Running Django maintenance tasks..."
    
    # Check for pending migrations
    log_info "Checking for pending migrations..."
    if $PYTHON_CMD manage.py showmigrations --plan | grep -q '\[ \]'; then
        log_warning "There are pending migrations. Consider running '$PYTHON_CMD manage.py migrate'"
    else
        log_info "No pending migrations found"
    fi
    
    # Collect static files if in production-like environment
    if [[ "${DJANGO_ENV:-development}" != "development" ]]; then
        log_info "Collecting static files..."
        $PYTHON_CMD manage.py collectstatic --noinput --clear
    fi
    
    # Clear expired sessions
    log_info "Clearing expired sessions..."
    $PYTHON_CMD manage.py clearsessions || {
        log_warning "Could not clear expired sessions"
    }
    
    log_success "Django maintenance completed"
}

# Clean Docker resources (if Docker is used)
clean_docker_resources() {
    progress "Cleaning Docker resources..."
    
    if command -v docker &> /dev/null; then
        log_info "Cleaning unused Docker images..."
        docker image prune -f || true
        
        log_info "Cleaning unused Docker containers..."
        docker container prune -f || true
        
        log_info "Cleaning unused Docker networks..."
        docker network prune -f || true
        
        log_info "Cleaning unused Docker volumes..."
        docker volume prune -f || true
        
        log_success "Docker resources cleaned"
    else
        log_info "Docker not found. Skipping Docker cleanup."
    fi
}

# Final system cleanup
final_cleanup() {
    progress "Performing final cleanup..."
    
    # Clean temporary directories
    if [[ -d "tmp" ]]; then
        rm -rf tmp/
        log_info "Removed tmp directory"
    fi
    
    # Clean log files older than 7 days
    if [[ -d "logs" ]]; then
        find logs/ -name "*.log" -mtime +7 -delete 2>/dev/null || true
        log_info "Cleaned old log files"
    fi
    
    # Update file permissions for scripts
    chmod +x *.sh 2>/dev/null || true
    
    log_success "Final cleanup completed"
}

# Main execution
main() {
    echo "==============================================================================="
    echo "           Evolve Backend Environment Cleanup and Update Script              "
    echo "==============================================================================="
    echo ""
    
    local start_time=$(date +%s)
    
    # Cache sudo credentials for potential password prompts (e.g., during brew operations)
    log_info "Caching sudo credentials (you may be prompted for your password)..."
    if sudo -v; then
        log_success "Sudo credentials cached successfully"
    else
        log_warning "Failed to cache sudo credentials. Some operations may prompt for password later."
    fi
    
    check_prerequisites
    clean_django_cache
    update_python_dependencies
    update_system_packages
    clean_pip_cache
    django_maintenance
    clean_docker_resources
    final_cleanup
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "==============================================================================="
    log_success "Environment cleanup and update completed successfully!"
    log_info "Total execution time: ${duration} seconds"
    echo ""
    log_info "Summary of actions performed:"
    log_info "✓ Cleaned Django cache and temporary files"
    log_info "✓ Updated Python dependencies"
    log_info "✓ Updated system packages (Homebrew)"
    log_info "✓ Cleaned pip cache"
    log_info "✓ Performed Django maintenance"
    log_info "✓ Cleaned Docker resources (if available)"
    log_info "✓ Performed final system cleanup"
    echo ""
    log_info "Next steps:"
    log_info "• Run tests to ensure everything works correctly"
    log_info "• Check for any new migrations: $PYTHON_CMD manage.py makemigrations"
    log_info "• Consider running: $PYTHON_CMD manage.py check"
    echo "==============================================================================="
}

# Run main function
main "$@"

