# Evolve Backend

## Documentation

To build the documentation:

```bash
cd docs
make html
```

Then open `docs/build/html/index.html` in your browser.

## Development Setup

1. Create and activate virtual environment:

```bash
python -m venv venv_evolve
source venv_evolve/bin/activate  # On Unix/macOS
```

2. Install requirements:

```bash
pip install -r requirements.txt
```

3. Run migrations:

```bash
python manage.py migrate
```

4. Run development server:

```bash
python manage.py runserver
```

````

2. Add a `.gitignore` file if you haven't already:
```gitignore:evolve-backend/.gitignore
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Django
*.log
local_settings.py
db.sqlite3
db.sqlite3-journal
media/
staticfiles/

# Virtual Environment
venv/
venv_evolve/
ENV/

# Documentation
docs/_build/
docs/build/

# IDE
.idea/
.vscode/
*.swp
*.swo
````

3. Update your requirements.txt:

```bash
pip freeze > requirements.txt
```
