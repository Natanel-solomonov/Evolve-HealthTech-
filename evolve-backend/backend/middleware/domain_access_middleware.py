from django.http import Http404
from django.conf import settings


class DomainAccessMiddleware:
    """
    Middleware to control domain access and path restrictions for different environments.
    
    This middleware enforces domain-specific access rules:
    - Admin URL is only accessible via API_HOST.
    - API_HOST (api.joinevolve.app) has User-Agent restrictions for all access.
    - PUBLIC_HOSTS (e.g., www.joinevolve.app) have restricted path access.
    - DEVELOPMENT_HOSTS (Railway, localhost) have full access to non-admin paths.
    - All other domains/paths are blocked.
    """

    def __init__(self, get_response):
        """
        Initialize the middleware with domain configurations.
        """
        self.get_response = get_response
        
        # Admin URL Configuration
        self.ADMIN_URL_PREFIX = getattr(settings, 'ADMIN_URL_PREFIX', '/unique-admin-prefix-not-set-in-settings/')
        if not self.ADMIN_URL_PREFIX.startswith('/'):
            self.ADMIN_URL_PREFIX = '/' + self.ADMIN_URL_PREFIX
        # Ensure admin prefix that represents a directory ends with a slash
        if self.ADMIN_URL_PREFIX != '/' and not self.ADMIN_URL_PREFIX.endswith('/'):
            self.ADMIN_URL_PREFIX += '/'

        # Host Configurations
        self.API_HOST = 'api.joinevolve.app'
        
        self.PUBLIC_HOSTS = [
            'www.joinevolve.app',
            'joinevolve.app',
            'waitlist.joinevolve.app'  
        ]
        
        # DEVELOPMENT_HOSTS allow more permissive access for non-admin paths
        self.DEVELOPMENT_HOSTS = [
            getattr(settings, 'RAILWAY_DOMAIN', None), # Get Railway domain, if configured
            '127.0.0.1:8080',  # Common local dev server
            'localhost:8080',  # Another common local dev server
            'localhost',       # Accessing via localhost without port
            '127.0.0.1'        # Accessing via 127.0.0.1 without port
        ]
        # Filter out None from DEVELOPMENT_HOSTS in case RAILWAY_DOMAIN is not set and defaults to None
        self.DEVELOPMENT_HOSTS = [host for host in self.DEVELOPMENT_HOSTS if host]

        # Define allowed paths for the public hosts (includes root)
        self.ALLOWED_PATHS_ON_PUBLIC_HOSTS = [
            '/',  # Root path must be explicitly allowed
            '/position',
            '/waitlist',
            '/universities/autocomplete',
            '/r'  # Typically for referral links like /r/<code>
        ]

        # Define allowed User-Agent strings for the API_HOST
        self.ALLOWED_USER_AGENTS_FOR_API_HOST = [
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15'
        ]

    def __call__(self, request):
        """
        Process the request and enforce domain access rules.
        """
        host = request.get_host()
        path = request.path
        user_agent = request.META.get('HTTP_USER_AGENT', '')

        is_admin_path = path.startswith(self.ADMIN_URL_PREFIX)

        # Rule 1: Admin path handling (highest priority for this path)
        if is_admin_path:
            if host == self.API_HOST:
                if user_agent not in self.ALLOWED_USER_AGENTS_FOR_API_HOST:
                    raise Http404(f"Access to admin from this device on {self.API_HOST} is not allowed.")
                # If host and user agent are correct for admin, allow access
                return self.get_response(request)
            else:
                # Admin path requested on a host other than API_HOST
                raise Http404(f"Admin interface ({self.ADMIN_URL_PREFIX}) is only accessible via {self.API_HOST}.")

        # Rule 2: API_HOST (api.joinevolve.app) handling for non-admin paths
        # This block is reached only if path is NOT an admin path.
        if host == self.API_HOST:
            if user_agent not in self.ALLOWED_USER_AGENTS_FOR_API_HOST:
                raise Http404(f"Access to {self.API_HOST} from this device is not allowed.")
            # User agent is fine for non-admin path on API_HOST
            return self.get_response(request)

        # Rule 3: Public host path restrictions
        # This block is reached if host is not API_HOST and path is not admin.
        if host in self.PUBLIC_HOSTS:
            is_path_allowed_on_public = False
            if path == '/' and '/' in self.ALLOWED_PATHS_ON_PUBLIC_HOSTS:
                is_path_allowed_on_public = True
            else:
                for allowed_prefix in self.ALLOWED_PATHS_ON_PUBLIC_HOSTS:
                    # Ensure allowed_prefix is not just '/' for startswith, 
                    # or that path is not just '/' to avoid double-matching root.
                    if allowed_prefix != '/' and path.startswith(allowed_prefix):
                        is_path_allowed_on_public = True
                        break
            
            if not is_path_allowed_on_public:
                raise Http404(f"The path '{path}' is not available on the domain '{host}'.")
            return self.get_response(request)

        # Rule 4: Development hosts (full access for non-admin paths)
        # This block is reached if host is not API_HOST, not PUBLIC_HOSTS, and path is not admin.
        if host in self.DEVELOPMENT_HOSTS:
            # Admin paths on these hosts are already blocked by Rule 1.
            # Any other path is allowed for development ease.
            return self.get_response(request)

        # Rule 5: Default block for any other host or unhandled condition
        raise Http404(f"Access from domain '{host}' is not permitted or the requested path '{path}' is not recognized for this domain.")