from django.conf import settings
from django.http import Http404, HttpResponseForbidden

class IpRestrictAdminMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response
        # Get the admin URL prefix and allowed IPs from settings
        # We use getattr to provide defaults if the settings are not defined,
        # though it's better to ensure they are defined.
        self.admin_url_prefix = getattr(settings, 'ADMIN_URL_PREFIX', 'system-dashboard/')
        # Ensure admin_url_prefix starts and ends with a slash for consistent matching
        if not self.admin_url_prefix.startswith('/'):
            self.admin_url_prefix = '/' + self.admin_url_prefix
        if not self.admin_url_prefix.endswith('/'):
            self.admin_url_prefix += '/'
            
        # settings.ALLOWED_ADMIN_IPS is now expected to be a list of cleaned IP strings from settings.py
        self.allowed_admin_ips = getattr(settings, 'ALLOWED_ADMIN_IPS', [])

    def __call__(self, request):
        # Check if the request path starts with the admin URL prefix
        if request.path.startswith(self.admin_url_prefix):
            # Get the client's IP address
            # HTTP_X_FORWARDED_FOR is used when behind a proxy
            x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
            if x_forwarded_for:
                client_ip = x_forwarded_for.split(',')[0].strip()
            else:
                client_ip = request.META.get('REMOTE_ADDR')

            if not self.allowed_admin_ips:
                # If ALLOWED_ADMIN_IPS is empty, deny all access to admin by default for safety.
                raise Http404("Admin access is restricted: No IPs are allowed.")

            if client_ip not in self.allowed_admin_ips:
                raise Http404(f"Admin access from IP {client_ip} is denied.")

        response = self.get_response(request)
        return response 