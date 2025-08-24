import os
import shutil
import subprocess
import re
from django.core.management.base import BaseCommand
from django.conf import settings

class Command(BaseCommand):
    help = 'Imports and integrates a React-based website from a git repository.'

    def add_arguments(self, parser):
        parser.add_argument('repo_url', type=str, help='The URL of the git repository to import.')

    def handle(self, *args, **options):
        repo_url = options['repo_url']
        temp_dir = os.path.join(settings.BASE_DIR, 'temp_portal_build')
        portal_base_path = '/portal/'

        self.stdout.write(self.style.SUCCESS(f'Starting import from {repo_url}...'))

        # 1. Clone repository
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)
        self.stdout.write(self.style.SUCCESS(f'Cloning repository into {temp_dir}...'))
        try:
            subprocess.run(['git', 'clone', repo_url, temp_dir], check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            self.stderr.write(self.style.ERROR(f'Failed to clone repository: {e.stderr}'))
            return

        # 2. Modify vite.config.ts and App.tsx before build
        vite_config_path = os.path.join(temp_dir, 'vite.config.ts')
        app_tsx_path = os.path.join(temp_dir, 'src', 'App.tsx')

        try:
            # Add base to vite.config.ts
            with open(vite_config_path, 'r+') as f:
                content = f.read()
                if "base:" not in content:
                    content = re.sub(r'(export default defineConfig\(\({ mode }\) => \({)', rf'\g<1>\n  base: "{portal_base_path}",', content)
                    f.seek(0)
                    f.write(content)
                    f.truncate()
            
            # Add basename to BrowserRouter in App.tsx
            with open(app_tsx_path, 'r+') as f:
                content = f.read()
                if 'basename=' not in content:
                    content = content.replace('<BrowserRouter>', f'<BrowserRouter basename="{portal_base_path.rstrip("/")}">')
                    f.seek(0)
                    f.write(content)
                    f.truncate()

        except IOError as e:
            self.stderr.write(self.style.ERROR(f'Failed to modify source files before build: {e}'))
            return

        # 3. Build the React project
        self.stdout.write(self.style.SUCCESS('Installing dependencies and building project...'))
        try:
            # Use shell=True on Windows, otherwise it's better to pass a list of args
            npm_install_command = ['npm', 'install']
            npm_build_command = ['npm', 'run', 'build']
            if os.name == 'nt':
                npm_install_command.append('--shell=True')
                npm_build_command.append('--shell=True')

            subprocess.run(npm_install_command, cwd=temp_dir, check=True, capture_output=True, text=True)
            subprocess.run(npm_build_command, cwd=temp_dir, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            self.stderr.write(self.style.ERROR(f'Failed to build project: {e.stderr}'))
            return

        build_dir = os.path.join(temp_dir, 'dist')
        if not os.path.exists(build_dir):
            self.stderr.write(self.style.ERROR('Build directory "dist" not found.'))
            return

        # 4. Integrate into Django
        website_app_dir = os.path.join(settings.BASE_DIR, 'website')
        static_dir = os.path.join(website_app_dir, 'static', 'website')
        templates_dir = os.path.join(website_app_dir, 'templates', 'website')

        # Clear old files
        if os.path.exists(static_dir):
            shutil.rmtree(static_dir)
        os.makedirs(static_dir, exist_ok=True)
        
        if not os.path.exists(templates_dir):
            os.makedirs(templates_dir)

        self.stdout.write(self.style.SUCCESS('Copying built files to website app...'))
        # Copy assets from dist/assets to static/website/assets
        assets_src = os.path.join(build_dir, 'assets')
        assets_dest = os.path.join(static_dir, 'assets')
        if os.path.exists(assets_src):
            shutil.copytree(assets_src, assets_dest, dirs_exist_ok=True)
        
        # Copy other root files from dist to static/website
        for item in os.listdir(build_dir):
            s = os.path.join(build_dir, item)
            d = os.path.join(static_dir, item)
            if os.path.isfile(s) and item != 'index.html':
                 shutil.copy2(s, d)

        # Move index.html to templates
        index_html_src = os.path.join(build_dir, 'index.html')
        index_html_dest = os.path.join(templates_dir, 'index.html')
        if os.path.exists(index_html_src):
            shutil.move(index_html_src, index_html_dest)

        # 5. Modify index.html for Django static files
        self.stdout.write(self.style.SUCCESS('Updating index.html with Django static tags...'))
        try:
            with open(index_html_dest, 'r+') as f:
                content = f.read()
                # Add {% load static %}
                if not content.lstrip().startswith('{% load static %}'):
                    content = '{% load static %}\n' + content
                
                # Replace asset paths, accounting for the base path
                base_path_no_slash = portal_base_path.strip('/')
                content = re.sub(r'src="/' + base_path_no_slash + r'/assets/(.*?)"', r"src=`{% static 'website/assets/\1' %}`", content)
                content = re.sub(r'href="/' + base_path_no_slash + r'/assets/(.*?)"', r"href=`{% static 'website/assets/\1' %}`", content)

                # Add favicon if not present
                if '<link rel="icon"' not in content:
                    content = re.sub(r'(</head>)', r"    <link rel=\"icon\" href=\"{% static 'website/favicon.ico' %}\">\n\1", content)

                f.seek(0)
                f.write(content)
                f.truncate()
        except IOError as e:
            self.stderr.write(self.style.ERROR(f'Failed to modify index.html: {e}'))
            return
            
        # 6. Cleanup
        self.stdout.write(self.style.SUCCESS('Cleaning up temporary files...'))
        shutil.rmtree(temp_dir)

        self.stdout.write(self.style.SUCCESS('Website import completed successfully!')) 