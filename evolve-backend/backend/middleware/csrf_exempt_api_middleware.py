"""
CSRF Exempt API Middleware

This middleware exempts API endpoints from CSRF protection when using JWT authentication.
Since JWT tokens provide sufficient authentication for API endpoints, CSRF protection 
is not necessary and can interfere with mobile app requests.
"""

from django.utils.deprecation import MiddlewareMixin
from django.views.decorators.csrf import csrf_exempt


class CSRFExemptAPIMiddleware(MiddlewareMixin):
    """
    Middleware to exempt API endpoints from CSRF protection.
    
    This middleware checks if the request is going to an API endpoint
    (based on URL path starting with '/api/') and exempts it from CSRF protection.
    This is particularly useful for JWT-authenticated API endpoints where CSRF
    protection is not necessary.
    """
    
    def process_view(self, request, view_func, view_args, view_kwargs):
        """
        Exempt API endpoints from CSRF protection.
        
        Args:
            request: The incoming HTTP request
            view_func: The view function that will handle the request
            view_args: Arguments passed to the view function
            view_kwargs: Keyword arguments passed to the view function
            
        Returns:
            None if request should be processed normally,
            or the result of the exempted view function
        """
        # Check if this is an API request
        if request.path.startswith('/api/'):
            # Apply CSRF exemption to the view function
            exempted_view = csrf_exempt(view_func)
            return exempted_view(request, *view_args, **view_kwargs)
        
        # For non-API requests, proceed normally
        return None 