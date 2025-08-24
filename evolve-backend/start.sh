#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Starting Django application..."

# Run database migrations
echo "Running database migrations..."
python manage.py migrate

# Start the Django development server
echo "Starting Django server on port $PORT..."
python manage.py runserver 0.0.0.0:$PORT 