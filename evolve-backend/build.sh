#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Building backend only - skipping frontend build for Railway deployment..."

# FRONTEND BUILD DISABLED FOR BACKEND-ONLY DEPLOYMENT
# # Check if we're in a Railway deployment (no .git directory) or local development
# if [ ! -d ".git" ]; then
#     echo "Railway deployment detected - cloning frontend repository..."
#     # Remove any existing frontend directory (in case of partial copy)
#     rm -rf frontend
#     
#     # Check if GITHUB_TOKEN is set for private repo access
#     if [ -n "$GITHUB_TOKEN" ]; then
#         echo "Using GitHub token for private repository access..."
#         # For personal access tokens (classic), use this format
#         git clone https://${GITHUB_TOKEN}:x-oauth-basic@github.com/marcus-evolve/new-online-portal.git frontend
#     else
#         echo "No GitHub token found, attempting public repository clone..."
#         git clone https://github.com/marcus-evolve/new-online-portal.git frontend
#     fi
#     
#     # Check if clone was successful
#     if [ ! -d "frontend" ]; then
#         echo "ERROR: Failed to clone frontend repository!"
#         echo "If the repository is private, please set GITHUB_TOKEN environment variable in Railway."
#         echo "Make sure your token has 'repo' scope permissions."
#         echo "The token should be a personal access token (classic) with full 'repo' scope."
#         exit 1
#     fi
# else
#     echo "Local development detected - using git submodule..."
#     # Initialize submodules if needed
#     git submodule update --init --recursive
# fi

# # Install Node.js dependencies for frontend
# echo "Installing frontend dependencies..."
# cd frontend
# npm install

# # Build Vite assets for production
# echo "Building Vite assets for production..."
# npm run build

# # Go back to root directory
# cd ..

# Install Python dependencies
echo "Installing Python dependencies..."
pip install -r requirements.txt

# Collect static files (includes the built Vite assets)
echo "Collecting static files..."
python manage.py collectstatic --noinput

echo "Build completed successfully!" 