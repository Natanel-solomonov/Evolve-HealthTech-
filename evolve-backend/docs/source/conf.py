import os
import sys
import django
sys.path.insert(0, os.path.abspath('../../'))

# Django settings configuration
os.environ['DJANGO_SETTINGS_MODULE'] = 'backend.settings'
django.setup()

# Project information
project = 'Evolve Backend'
copyright = '2025 Evolve'
author = 'Natanel Solomonov, Marcus Sypher, Nathan Danko'
release = '1.0.0'

# Extensions
extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.viewcode',
    'sphinx.ext.napoleon',
    'sphinx.ext.autosummary',
    'sphinx.ext.intersphinx',
    'sphinxcontrib_django',
]

# Theme settings
html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']

# autodoc settings
autodoc_member_order = 'bysource'
autodoc_default_options = {
    'members': True,
    'show-inheritance': True,
    'undoc-members': True,
    'special-members': '__init__',
}

# Add source code path
sys.path.insert(0, os.path.abspath('../../api'))
sys.path.insert(0, os.path.abspath('../../backend'))

# Napoleon settings
napoleon_google_docstring = True
napoleon_numpy_docstring = True
napoleon_include_init_with_doc = True
napoleon_include_private_with_doc = True
napoleon_include_special_with_doc = True
napoleon_use_admonition_for_examples = True
napoleon_use_admonition_for_notes = True
napoleon_use_admonition_for_references = True
napoleon_use_ivar = True
napoleon_use_param = True
napoleon_use_rtype = True
napoleon_type_aliases = None