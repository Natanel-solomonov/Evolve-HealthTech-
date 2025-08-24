from pathlib import Path
import os
from decouple import config
import dj_database_url
from dotenv import load_dotenv
from datetime import timedelta

# --- Core Settings ---
AUTH_USER_MODEL = 'api.AppUser'
BASE_DIR = Path(__file__).resolve().parent.parent

# --- Environment Configuration ---
load_dotenv(os.path.join(BASE_DIR, '.env'))

# --- Security Settings ---
SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=True, cast=bool)
COMPRESS_ENABLED = config('COMPRESS_ENABLED', default=False, cast=bool)
# Get ALLOWED_HOSTS from environment or use default
allowed_hosts_from_env = config('ALLOWED_HOSTS', default='127.0.0.1,localhost,10.0.0.229,172.20.10.8,evolve-backend-production4701250738638064907896437.up.railway.app')
ALLOWED_HOSTS = allowed_hosts_from_env.split(',')
CSRF_TRUSTED_ORIGINS = ['https://*.railway.app']
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
RAILWAY_DOMAIN = config('RAILWAY_DOMAIN')

# Additional Security Settings
if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = 2592000  # 30 days
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_REFERRER_POLICY = 'same-origin'
else:
    # Development settings
    SECURE_SSL_REDIRECT = False
    SESSION_COOKIE_SECURE = False
    CSRF_COOKIE_SECURE = False
    SECURE_HSTS_SECONDS = 0
    SECURE_HSTS_INCLUDE_SUBDOMAINS = False
    SECURE_HSTS_PRELOAD = False
    SECURE_CONTENT_TYPE_NOSNIFF = True
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_REFERRER_POLICY = 'same-origin'

# IP Restriction for Admin
ENABLE_ADMIN_IP_RESTRICTION = config('ENABLE_ADMIN_IP_RESTRICTION', default=True, cast=bool)
raw_admin_ips_str = config('ALLOWED_ADMIN_IPS', default='127.0.0.1')
ALLOWED_ADMIN_IPS = [ip.strip().strip("'").strip('"') for ip in raw_admin_ips_str.split(',') if ip.strip()]

# --- Twilio Settings ---
TWILIO_ACCOUNT_SID = config('TWILIO_ACCOUNT_SID')
TWILIO_AUTH_TOKEN = config('TWILIO_AUTH_TOKEN')
TWILIO_USE_FAKE = config('TWILIO_USE_FAKE', default=True, cast=bool)
TWILIO_VERIFY_SERVICE_SID = config('TWILIO_VERIFY_SERVICE_SID')

# --- Application Configuration ---
INSTALLED_APPS = [
    # Django Core Apps
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.auth',
    'django.contrib.admin',

    
    # Custom Apps
    'api',
    'fitness',
    'nutrition',
    'website',
    'finances',
    'max',
    'recipes',
    'medications',
    
    # Third-Party Apps
    'rest_framework',
    'rest_framework_simplejwt.token_blacklist',
    'whitenoise',
    'nested_admin',
    'compressor',
    # Added for Vite integration
    'django_vite',
]

# --- Middleware Configuration ---
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    # 'backend.middleware.domain_access_middleware.DomainAccessMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    # CSRF exempt middleware for API endpoints (must be before CsrfViewMiddleware)
    'backend.middleware.csrf_exempt_api_middleware.CSRFExemptAPIMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

if ENABLE_ADMIN_IP_RESTRICTION:
    # Insert the IP restriction middleware after SecurityMiddleware if enabled
    # Find the index of SecurityMiddleware to insert after it, or insert at the beginning if not found (though it should be there)
    try:
        security_middleware_index = MIDDLEWARE.index('django.middleware.security.SecurityMiddleware')
        MIDDLEWARE.insert(security_middleware_index + 1, 'backend.middleware.ip_restrict_admin_middleware.IpRestrictAdminMiddleware')
    except ValueError:
        # Fallback: insert at a reasonable position if SecurityMiddleware wasn't found (e.g., at the start or after another known middleware)
        MIDDLEWARE.insert(1, 'backend.middleware.ip_restrict_admin_middleware.IpRestrictAdminMiddleware') 

# --- URL and WSGI Configuration ---
ROOT_URLCONF = 'backend.urls'
ADMIN_URL_PREFIX = 'csaRlJLWcz02L9WRbuAs1c4mFJUyIKL6-system-dashboard-q5U9k7TVMmU4q1BA4it0ELqQaySozLYn/' # Define admin url prefix
WSGI_APPLICATION = 'backend.wsgi.application'

# --- Template Configuration ---
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [
            os.path.join(BASE_DIR, 'api', 'templates'),
            os.path.join(BASE_DIR, 'frontend', 'templates'),
        ],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

# --- Database Configuration ---
DATABASES = {
    'default': dj_database_url.config(default=config('DATABASE_URL'))
}

# Add performance optimizations for large datasets
if 'postgresql' in DATABASES['default']['ENGINE']:
    DATABASES['default']['OPTIONS'] = {
        'connect_timeout': 60,
        'options': '-c statement_timeout=300000'  # 5 minutes timeout for statements
    }
    # Connection pooling settings for better performance
    DATABASES['default']['CONN_MAX_AGE'] = 600  # 10 minutes

# --- Authentication Configuration ---
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

# --- Internationalization ---
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# --- Static and Media Files Configuration ---
STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')
STATICFILES_DIRS = [
    os.path.join(BASE_DIR, 'api', 'static'),
    os.path.join(BASE_DIR, 'website', 'static'),
    # Include built frontend assets (prod build)
    os.path.join(BASE_DIR, 'frontend', 'dist'),
]

STATICFILES_FINDERS = (
    'django.contrib.staticfiles.finders.FileSystemFinder',
    'django.contrib.staticfiles.finders.AppDirectoriesFinder',
    'compressor.finders.CompressorFinder',
)

# --- Static File Compression ---
COMPRESS_JS_FILTERS = [
    'compressor.filters.jsmin.JSMinFilter',  # fallback
    'compressor.filters.terser.TerserFilter',  # use Terser if available
]

MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'api', 'media')

# --- WhiteNoise Configuration ---
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'
WHITENOISE_ROOT = os.path.join(BASE_DIR, 'frontend', 'dist')

# --- Django-Vite Configuration ---
DJANGO_VITE_ASSETS_PATH = os.path.join(BASE_DIR, "frontend", "dist")
DJANGO_VITE_DEV_MODE = DEBUG

# --- REST Framework Configuration ---
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'api.authentication.AppUserJWTAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'EXCEPTION_HANDLER': 'rest_framework.views.exception_handler',
    'DEFAULT_RENDERER_CLASSES': (
        'rest_framework.renderers.JSONRenderer',
    ),
    'DEFAULT_PARSER_CLASSES': (
        'rest_framework.parsers.JSONParser',
        'rest_framework.parsers.FormParser',
        'rest_framework.parsers.MultiPartParser',
    ),
    'FORMAT_SUFFIX_KWARG': 'format',
}

# --- JWT Configuration ---
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(hours=2),  # Extended from 30 minutes to 2 hours
    "REFRESH_TOKEN_LIFETIME": timedelta(days=30),  # Extended to 30 days for user convenience
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN": True,

    "ALGORITHM": "HS256",
    "SIGNING_KEY": SECRET_KEY,
    "VERIFYING_KEY": None,

    "AUTH_HEADER_TYPES": ("Bearer",),
    "AUTH_HEADER_NAME": "HTTP_AUTHORIZATION",
    "USER_ID_FIELD": "id",
    "USER_ID_CLAIM": "user_id",

    "AUTH_TOKEN_CLASSES": ("rest_framework_simplejwt.tokens.AccessToken",),
    "TOKEN_TYPE_CLAIM": "token_type",

    "JTI_CLAIM": "jti",
}

# --- Logging Configuration ---
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '[{asctime}] {levelname} {name} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{levelname} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
    },
    'loggers': {
        'api': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': False,
        },
        # Suppress staticfiles warnings about missing directories vite
        'django.contrib.staticfiles': {
            'handlers': ['console'],
            'level': 'ERROR',  # Only show errors, not warnings
            'propagate': False,
        },
    },
}

# --- Caching Configuration for Large Datasets ---
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': config('REDIS_URL', default='redis://127.0.0.1:6379/1'),
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            'COMPRESSOR': 'django_redis.compressors.zlib.ZlibCompressor',
            'IGNORE_EXCEPTIONS': True,  # Don't fail if Redis is down
        },
        'TIMEOUT': 300,  # 5 minutes default timeout
        'KEY_PREFIX': 'evolve_search',
    },
    'search_cache': {
        'BACKEND': 'django_redis.cache.RedisCache', 
        'LOCATION': config('REDIS_URL', default='redis://127.0.0.1:6379/2'),
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            'COMPRESSOR': 'django_redis.compressors.zlib.ZlibCompressor',
            'IGNORE_EXCEPTIONS': True,
        },
        'TIMEOUT': 900,  # 15 minutes for search results
        'KEY_PREFIX': 'food_search',
    }
}

# --- Default Primary Key Field Type ---
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# --- Vite / django-vite Configuration ---
DJANGO_VITE = {
    "default": {
        "dev_mode": DEBUG,
        "dev_server_port": 5173,
        # Add these for production – leave blank so that STATIC_URL is not duplicated
        "static_url_prefix": "",
        "manifest_path": os.path.join(BASE_DIR, "frontend", "dist", ".vite", "manifest.json") if not DEBUG else "",
    }
}

# Feature Flags for Safe Production Rollouts
FEATURES = {
    'USE_OPTIMIZED_SEARCH': True,  # Set to False to rollback to original search
    'ENABLE_SEARCH_ANALYTICS': True,  # Track search performance metrics
}