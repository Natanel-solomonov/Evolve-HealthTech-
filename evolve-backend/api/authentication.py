from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from django.utils.translation import gettext_lazy as _
from django.conf import settings
import uuid
from .models import AppUser 

class AppUserJWTAuthentication(JWTAuthentication):
    """
    Custom JWT Authentication class that handles authentication for AppUser model.
    
    This class extends the default JWTAuthentication to provide specific handling
    for the AppUser model, including proper error handling and user validation.
    """

    def get_user(self, validated_token):
        """
        Retrieves and validates a user from the JWT token.
        
        Args:
            validated_token (dict): The validated JWT token containing user information
            
        Returns:
            AppUser: The authenticated user instance
            
        Raises:
            InvalidToken: If the token is invalid or missing required claims
            TokenError: If there's an error retrieving the user
            AppUser.DoesNotExist: If the user doesn't exist in the database
        """
        # Extract user ID from token
        try:
            # Get the USER_ID_FIELD from simplejwt settings, default to 'user_id'
            # This is the key for the user ID in the token payload.
            simple_jwt_settings = getattr(settings, 'SIMPLE_JWT', {})
            user_id_claim_name = simple_jwt_settings.get('USER_ID_CLAIM', 'user_id')
            user_id = validated_token[user_id_claim_name]
        except KeyError:
            # This means the token payload doesn't have the expected user ID claim.
            raise InvalidToken(_("Token contained no recognizable user identification"))
        except TypeError: # Handle if validated_token is not a dict (should not happen with valid token)
             raise InvalidToken(_("Validated token is not in the expected format."))

        # Retrieve user from database
        try:
            # Explicitly use AppUser model here and query by its primary key field name directly.
            # AppUser._meta.pk.name will give you the actual primary key field name (e.g., 'id')
            pk_field_name = AppUser._meta.pk.name
            user = AppUser.objects.get(**{pk_field_name: user_id})
        except AppUser.DoesNotExist:
            # This will lead to the "user_not_found" error.
            # We re-raise it so that simplejwt's default error handling can take over
            # and produce the consistent "user_not_found" error code.
            raise 
        except Exception as e: 
            # Catch other potential errors during user retrieval
            # Log this error for debugging
            # import logging
            # logger = logging.getLogger(__name__)
            # logger.error(f"Error retrieving user from AppUser model: {e}", exc_info=True)
            raise TokenError(_(f"An unexpected error occurred while attempting to get the user from the token: {e}"))

        # Assuming your AppUser model doesn't have an 'is_active' field like Django's default User model.
        # If it does, you should check it:
        # if hasattr(user, 'is_active') and not user.is_active:
        #     raise TokenError(_("User is inactive"))

        return user 