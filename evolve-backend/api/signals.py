from django.db.models.signals import post_save, post_delete, pre_save, m2m_changed, pre_delete
from django.dispatch import receiver
from django.utils import timezone
from .models import (
    Member, FriendGroupEvent, FriendGroup, AppUser, AppUserGoals,
    UserCompletedLog, UserScheduledActivity, Activity, AffiliatePromotion,
    UserExerciseMax, AffiliatePromotionRedemption, UserProduct
)
from website.models import WaitlistedAppUser
import logging
import requests
import os
import random
import string
from django.db.utils import IntegrityError

# Note: generate_activity_description is imported lazily to avoid circular imports

# --- Logging Configuration ---
logger = logging.getLogger(__name__)

# --- Twilio Configuration ---
TWILIO_ACCOUNT_SID = os.environ.get('TWILIO_ACCOUNT_SID')
TWILIO_AUTH_TOKEN = os.environ.get('TWILIO_AUTH_TOKEN')
TWILIO_FROM_NUMBER = os.environ.get('TWILIO_VIRTUAL_NUMBER', '+18447796600')
TWILIO_RECIPIENT_NUMBER = os.environ.get('TWILIO_RECIPIENT_NUMBER', '+16073428125')

# --- Helper Functions ---

def _send_twilio_sms(message_body, context_instance_id_for_logging):
    """
    Send SMS via Twilio API.
    
    Args:
        message_body (str): The message content to send
        context_instance_id_for_logging (int): ID of the related instance for logging purposes
    """
    if not all([TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER, TWILIO_RECIPIENT_NUMBER]):
        logger.error("Missing Twilio credentials or phone numbers in environment variables.")
        return

    twilio_url = f"https://api.twilio.com/2010-04-01/Accounts/{TWILIO_ACCOUNT_SID}/Messages.json"
    payload = {
        'To': TWILIO_RECIPIENT_NUMBER,
        'From': TWILIO_FROM_NUMBER,
        'Body': message_body
    }

    try:
        response = requests.post(
            twilio_url,
            data=payload,
            auth=(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        )
        response.raise_for_status()
        logger.info(f"SMS sent successfully regarding WaitlistedAppUser {context_instance_id_for_logging}. "
                   f"Message SID: {response.json().get('sid')}")
    except requests.exceptions.RequestException as e:
        logger.error(f"Error sending SMS regarding WaitlistedAppUser {context_instance_id_for_logging}: {e}", 
                    exc_info=True)
        if hasattr(e, 'response') and e.response is not None:
            logger.error(f"Twilio API Response: {e.response.text}")
    except Exception as e:
        logger.error(f"An unexpected error occurred while sending SMS for WaitlistedAppUser "
                    f"{context_instance_id_for_logging}: {e}", exc_info=True)

# --- Friend Group Member Signals ---

@receiver(post_save, sender=Member)
def log_member_joined(sender, instance, created, **kwargs):
    """
    Log an event when a new Member is added to a FriendGroup.
    
    Args:
        sender: The model class (Member)
        instance: The actual instance being saved
        created: Boolean indicating if this is a new instance
    """
    if created:
        try:
            FriendGroupEvent.objects.create(
                friend_group=instance.friend_group,
                user=instance.user,
                event_type='MEMBER_JOINED'
            )
            logger.info(f"Logged MEMBER_JOINED event for user {instance.user.id} in group {instance.friend_group.id}")
        except Exception as e:
            logger.error(f"Error creating MEMBER_JOINED event: {e}", exc_info=True)

@receiver(pre_delete, sender=Member)
def log_member_left(sender, instance, **kwargs):
    # instance is the Member object that was just deleted.
    # Its attributes like instance.user and instance.friend_circle_id should be accessed
    # before they potentially become invalid if the related objects are also GC'd or connections severed.

    user_obj = None
    circle_id_val = None

    try:
        user_obj = instance.user
        group_id_val = instance.friend_group_id # Get the ID before trying to access the related object
    except AppUser.DoesNotExist:
        logger.warning(f"Member {instance.pk} post_delete: Associated AppUser not found. Skipping MEMBER_LEFT event.")
        return
    except Exception as e: # Catch any other error accessing initial FKs (e.g. if instance itself is weirdly detached)
        logger.error(f"Member {instance.pk} post_delete: Error accessing user or friend_group_id: {e}. Skipping event.", exc_info=True)
        return

    if not group_id_val or not user_obj:
        logger.warning(f"Member {instance.pk} post_delete: group_id ({group_id_val}) or user_obj ({user_obj}) is invalid/None. Skipping MEMBER_LEFT event creation.")
        return

    try:
        FriendGroupEvent.objects.create(
            friend_group_id=group_id_val,
            user=user_obj,
            event_type='MEMBER_LEFT'
        )
        logger.info(f"Successfully created MEMBER_LEFT event for user {user_obj.id} from group {group_id_val}")

    except IntegrityError as ie:
        # This specifically catches the case where the friend_group_id FK constraint fails.
        # This is the expected behavior if the FriendGroup was deleted in the same transaction.
        logger.info(
            f"IntegrityError on creating MEMBER_LEFT event for user {user_obj.id} from group {group_id_val}. "
            f"This typically means the FriendGroup was deleted. Event not logged. Details: {ie}"
        )
    except Exception as e:
        # Catch any other unexpected error during FriendGroupEvent creation.
        logger.error(
            f"Unexpected error creating MEMBER_LEFT event for user {user_obj.id} (originally from group ID "
            f"{group_id_val}): {e}",
            exc_info=True
        )

# --- Activity Completion Signals ---

@receiver(post_save, sender=UserCompletedLog)
def log_activity_completed_in_circles(sender, instance, created, **kwargs):
    """
    Log an event in relevant FriendGroups when a user completes an activity.
    
    Args:
        sender: The model class (UserCompletedLog)
        instance: The actual instance being saved
        created: Boolean indicating if this is a new instance
    """
    if created:
        user = instance.user
        member_groups = FriendGroup.objects.filter(members=user)
        
        for group in member_groups:
            try:
                FriendGroupEvent.objects.create(
                    friend_group=group,
                    user=user,
                    event_type='ACTIVITY_COMPLETED',
                    completed_activity_log=instance
                )
                activity_name = instance.activity_name_at_completion
                logger.info(f"Logged ACTIVITY_COMPLETED event for user {user.id} in circle {circle.id} "
                          f"(Activity: {activity_name})")
            except Exception as e:
                logger.error(f"Error creating ACTIVITY_COMPLETED event in circle {circle.id}: {e}", exc_info=True)

# --- User Onboarding Signals ---

@receiver(post_save, sender=AppUserGoals)
def update_user_onboarding_status(sender, instance, created, **kwargs):
    """
    Update the AppUser's isOnboarded status when an AppUserGoals record is created.
    
    Args:
        sender: The model class (AppUserGoals)
        instance: The actual instance being saved
        created: Boolean indicating if this is a new instance
    """
    if created:
        user = instance.user
        if not user.isOnboarded:
            user.isOnboarded = True
            user.save(update_fields=['isOnboarded'])

# --- Waitlisted User Signals ---

_waitlisted_app_user_old_state = {}

@receiver(pre_save, sender=WaitlistedAppUser)
def store_old_waitlisted_app_user_state(sender, instance, **kwargs):
    """
    Store the current state of a WaitlistedAppUser before saving.
    
    Args:
        sender: The model class (WaitlistedAppUser)
        instance: The actual instance being saved
    """
    if instance.pk:
        try:
            current_db_instance = WaitlistedAppUser.objects.get(pk=instance.pk)
            _waitlisted_app_user_old_state[instance.pk] = {
                'first_name': current_db_instance.first_name,
                'last_name': current_db_instance.last_name,
            }
        except WaitlistedAppUser.DoesNotExist:
            _waitlisted_app_user_old_state.pop(instance.pk, None)
    elif instance.pk in _waitlisted_app_user_old_state:
        _waitlisted_app_user_old_state.pop(instance.pk, None)

@receiver(post_save, sender=WaitlistedAppUser)
def handle_waitlisted_user_changes(sender, instance, created, **kwargs):
    """
    Handle changes to WaitlistedAppUser and send appropriate SMS notifications.
    
    Args:
        sender: The model class (WaitlistedAppUser)
        instance: The actual instance being saved
        created: Boolean indicating if this is a new instance
    """
    old_state = _waitlisted_app_user_old_state.pop(instance.pk, None)

    if created:
        message_body = f"New waitlist sign-up: {instance.phone_number}. Position: {instance.position}."
        # _send_twilio_sms(message_body, instance.id)
    elif old_state:
        old_first_name = old_state.get('first_name')
        old_last_name = old_state.get('last_name')

        first_name_added = not old_first_name and instance.first_name
        last_name_added = not old_last_name and instance.last_name

        if first_name_added or last_name_added:
            full_name = f"{instance.first_name or ''} {instance.last_name or ''}".strip()
            message_body = f"User {instance.phone_number} (Pos: {instance.position}) added name: {full_name}."
            # _send_twilio_sms(message_body, instance.id)

# --- Scheduled Activity Signals ---

_user_scheduled_activity_old_instance_state = {}

@receiver(pre_save, sender=UserScheduledActivity)
def store_old_user_scheduled_activity_state(sender, instance, **kwargs):
    """
    Store the current state of a UserScheduledActivity before saving.
    
    Args:
        sender: The model class (UserScheduledActivity)
        instance: The actual instance being saved
    """
    if instance.pk:
        try:
            current_db_instance = UserScheduledActivity.objects.get(pk=instance.pk)
            _user_scheduled_activity_old_instance_state[instance.pk] = {
                'is_complete': current_db_instance.is_complete
            }
        except UserScheduledActivity.DoesNotExist:
            _user_scheduled_activity_old_instance_state.pop(instance.pk, None)
    elif instance.pk in _user_scheduled_activity_old_instance_state:
        _user_scheduled_activity_old_instance_state.pop(instance.pk, None)

@receiver(post_save, sender=UserScheduledActivity)
def handle_scheduled_activity_completion_log(sender, instance, created, **kwargs):
    """
    Handle completion status changes for UserScheduledActivity and create appropriate logs.
    Also generates AI description when activity is marked as complete.
    
    Args:
        sender: The model class (UserScheduledActivity)
        instance: The actual instance being saved
        created: Boolean indicating if this is a new instance
    """
    old_state = _user_scheduled_activity_old_instance_state.pop(instance.pk, None)
    was_incomplete = old_state is not None and not old_state['is_complete']
    is_now_complete = instance.is_complete

    if is_now_complete and (created or was_incomplete):
        current_time = timezone.now()
        
        if instance.completed_at is None or (old_state and instance.completed_at != current_time):
            UserScheduledActivity.objects.filter(pk=instance.pk).update(completed_at=current_time)
            instance.refresh_from_db(fields=['completed_at'])

        UserCompletedLog.objects.get_or_create(
            user=instance.user,
            activity=instance.activity,
            source_scheduled_activity=instance,
            defaults={
                'activity_name_at_completion': instance.activity.name if instance.activity else "Unknown Activity",
                'description_at_completion': instance.activity.description if instance.activity else "",
                'completed_at': current_time,
                'points_awarded': instance.activity.default_point_value if instance.activity else 0,
                'is_adhoc': False
            }
        )
        logger.info(f"UserCompletedLog created for scheduled activity {instance.id} completion.")
        
        # Generate AI summary for completed activity (lazy import to avoid circular imports)
        try:
            from max.services import generate_activity_description
            
            # Only generate if summary doesn't already exist
            if not instance.generated_description:
                result = generate_activity_description(instance)
                if result.get('success'):
                    logger.info(f"AI summary generated for completed activity {instance.id}: {result['generated_description'][:50]}...")
                else:
                    logger.warning(f"Failed to generate AI summary for completed activity {instance.id}: {result.get('error', 'Unknown error')}")
            else:
                logger.debug(f"Skipping AI summary generation for activity {instance.id} - summary already exists")
        except ImportError:
            logger.debug("AI summary generation skipped - max.services not available (likely during migrations)")
        except Exception as e:
            logger.error(f"Error generating AI summary for completed activity {instance.id}: {str(e)}", exc_info=True)

    elif old_state and old_state['is_complete'] and not is_now_complete:
        if instance.completed_at is not None:
            UserScheduledActivity.objects.filter(pk=instance.pk).update(completed_at=None)
            instance.refresh_from_db(fields=['completed_at'])
        logger.info(f"Scheduled activity {instance.id} marked as incomplete, completed_at cleared.")

# --- User Exercise Max Signals ---

@receiver(pre_save, sender=UserExerciseMax)
def update_previous_maxes_on_1rm_change(sender, instance, **kwargs):
    """
    When a UserExerciseMax's one_rep_max is updated, move the old value
    and date to the previous_maxes list.
    """
    if instance.pk:  # Check if this is an update to an existing instance
        try:
            old_instance = UserExerciseMax.objects.get(pk=instance.pk)
        except UserExerciseMax.DoesNotExist:
            return # Should not happen if instance.pk exists, but good practice

        # Check if one_rep_max has actually changed
        if old_instance.one_rep_max != instance.one_rep_max:
            # Prepare the entry for previous_maxes
            previous_entry = {
                'value': old_instance.one_rep_max,
                'date': old_instance.date_recorded.isoformat(), # Store date as ISO string
                'unit': old_instance.unit # Also store the unit of the previous max
            }
            
            # Ensure previous_maxes is a list
            if instance.previous_maxes is None:
                instance.previous_maxes = []
            
            instance.previous_maxes.append(previous_entry)
            # By default, the date_recorded on the instance itself reflects when the *current* 1RM was achieved.
            # If the incoming instance.date_recorded is different from old_instance.date_recorded, 
            # it means the user is explicitly setting a date for the new 1RM. Otherwise, update it to now.
            if instance.date_recorded == old_instance.date_recorded:
                 instance.date_recorded = timezone.now().date() # Update the main record's date to today


@receiver(post_save, sender=AffiliatePromotionRedemption)
def create_user_product_on_redemption(sender, instance, created, **kwargs):
    """
    Automatically create a UserProduct record when a user redeems an affiliate promotion.
    This provides tracking for the "My Products" section.
    """
    
    if created and instance.user and instance.promotion:
        try:
            # Calculate expiry date (default to 1 year from redemption if not specified)
            expires_at = None
            if instance.promotion.end_date:
                # Set expiry to promotion end date or 1 year, whichever is longer
                one_year_from_now = timezone.now() + timezone.timedelta(days=365)
                expires_at = max(instance.promotion.end_date, one_year_from_now)
            else:
                expires_at = timezone.now() + timezone.timedelta(days=365)
            
            # Copy or determine product image
            product_image = None
            if instance.promotion.product_image:
                # For now, reference the same image. In production, you might want to copy it
                product_image = instance.promotion.product_image
            
            # Create the UserProduct record
            user_product = UserProduct.objects.create(
                user=instance.user,
                source_promotion=instance.promotion,
                source_redemption=instance,
                product_name=instance.promotion.title,
                product_description=instance.promotion.description,
                product_image=product_image,
                redeemed_at=instance.redeemed_at,
                expires_at=expires_at,
                affiliate_name=instance.promotion.affiliate.name,
                points_spent=instance.promotion.point_value or 0,
                original_value=instance.promotion.original_price,
                status='active'
                # category will be auto-determined by the model's save method
            )
            
            logger.info(f"UserProduct created for user {instance.user.phone} redeeming '{instance.promotion.title}'")
            
        except Exception as e:
            logger.error(f"Failed to create UserProduct for redemption {instance.id}: {str(e)}")


@receiver(post_delete, sender=AffiliatePromotionRedemption)
def handle_redemption_deletion(sender, instance, **kwargs):
    """
    Handle cleanup when a redemption is deleted.
    Optionally deactivate the associated UserProduct instead of deleting it.
    """
    
    try:
        if hasattr(instance, 'user_product') and instance.user_product:
            # Deactivate the product rather than delete it for audit trail
            instance.user_product.deactivate(reason='cancelled')
            logger.info(f"UserProduct deactivated due to redemption deletion: {instance.user_product.id}")
    except Exception as e:
        logger.error(f"Failed to handle UserProduct cleanup for deleted redemption: {str(e)}") 