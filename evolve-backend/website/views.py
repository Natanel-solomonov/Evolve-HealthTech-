from django.shortcuts import render, redirect, get_object_or_404
from django.views.decorators.csrf import csrf_exempt
from django.http import JsonResponse
import json
from api.models import Affiliate, AffiliatePromotion, AffiliatePromotionRedemption, AppUser
from django.utils.dateparse import parse_datetime
from .models import WaitlistedAppUser, University
import re
from django.db.models import Q # Import Q object
from django.contrib import messages # Import messages
from django.db.models import F # Import F object

def affiliate_dashboard(request):
    return render(request, 'website/index.html')

@csrf_exempt
def create_promotion(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            affiliate = Affiliate.objects.get(id=data['affiliate_id'])

            promo = AffiliatePromotion.objects.create(
                affiliate=affiliate,
                title=data['title'],
                description=data['description'],
                max_uses=data['max_uses'],
                uses_remaining=data['max_uses'],
                start_date=parse_datetime(data['start_date']),
                end_date=parse_datetime(data['end_date']),
            )
            return JsonResponse({'message': f'Promotion "{promo.title}" created.'})
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=400)

@csrf_exempt
def redeem_code(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user = AppUser.objects.get(id=data['user_id'])
            promo = AffiliatePromotion.objects.get(id=data['promotion_id'])

            if promo.uses_remaining <= 0:
                return JsonResponse({'error': 'No uses left for this promotion.'})

            AffiliatePromotionRedemption.objects.create(
                user=user,
                promotion=promo
            )
            promo.uses_remaining -= 1
            promo.save()

            return JsonResponse({'message': 'Promotion redeemed successfully.'})
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=400)


def my_promotions(request):
    # fetch and pass user promotions
    return render(request, 'website/my_promotions.html')

def my_affiliate_code(request):
    # fetch and pass user code
    return render(request, 'website/my_affiliate_code.html')

def waitlist_view(request):
    total_waitlisted_users = WaitlistedAppUser.objects.count()
    context = {
        'total_waitlisted_users': total_waitlisted_users
    }
    return render(request, 'waitlist.html', context)

def position_view(request):
    return render(request, 'position.html')

def user_position_view(request, user_id):
    waitlisted_user = get_object_or_404(WaitlistedAppUser, id=user_id)
    # Calculate user's current position (if dynamic)
    # For now, we use the stored position.
    # If you want a truly dynamic rank, you'd query based on created_at or some other logic.
    # Example: WaitlistedAppUser.objects.filter(created_at__lt=waitlisted_user.created_at).count() + 1
    
    context = {
        'user': waitlisted_user,
        'position': waitlisted_user.position, # Using the stored position
        'referral_link_url': request.build_absolute_uri(f'/r/{waitlisted_user.referral_link}'), # Assuming /r/ is your referral prefix
        'friends_invited_count': waitlisted_user.referrals,
        'domain': request.get_host() # To construct the full referral link like evolve.com/r/xxxx
    }
    return render(request, 'position.html', context)

def handle_referral_link(request, referral_code):
    # Store the referral code in the session
    # We will check for this in the waitlist_signup view
    request.session['referral_code'] = referral_code
    # Redirect to the main waitlist signup page
    return redirect('waitlist')

def waitlist_signup(request):
    context = {}
    if request.method == "POST":
        phone_number_input = request.POST.get("phone_number")
        first_name_input = request.POST.get("first_name") # Changed from name_input
        last_name_input = request.POST.get("last_name")   # Added for last name

        if phone_number_input:
            processed_phone_number = phone_number_input.replace("(", "").replace(")", "").replace(" ", "").replace("-", "")
            
            user, created = WaitlistedAppUser.objects.get_or_create(
                phone_number=processed_phone_number,
                defaults={
                    'first_name': first_name_input if first_name_input else '', # Changed
                    'last_name': last_name_input if last_name_input else '',   # Added
                }
            )
            
            if not created:
                updated = False
                if first_name_input and user.first_name != first_name_input: # Changed
                    user.first_name = first_name_input # Changed
                    updated = True
                if last_name_input and user.last_name != last_name_input: # Added
                    user.last_name = last_name_input # Added
                    updated = True
                if updated:
                    update_fields = []
                    if first_name_input and 'first_name' not in update_fields: update_fields.append('first_name') # Changed
                    if last_name_input and 'last_name' not in update_fields: update_fields.append('last_name') # Added
                    if update_fields: # Ensure not empty
                        user.save(update_fields=update_fields)
                messages.success(request, 'Welcome back! You are on the waitlist.')
            else:
                messages.success(request, 'Success! You have been added to the waitlist.')
                # --- BEGIN REFERRAL LOGIC ---
                referral_code = request.session.get('referral_code')
                if referral_code:
                    try:
                        referrer = WaitlistedAppUser.objects.get(referral_link=referral_code)
                        
                        if referrer.id != user.id: # Ensure the new user is not referring themselves
                            referrer.referrals = F('referrals') + 1
                            
                            new_position_target = None
                            if referrer.position is not None:
                                new_position_target = referrer.position - 5
                            
                            referrer.save(update_fields=['referrals'])
                            referrer.refresh_from_db(fields=['referrals']) # Get the updated referral count for logging

                            if new_position_target is not None:
                                old_pos_for_log = referrer.position # Position before change_position call
                                print(f"[INFO] Referrer {referrer.id} (current pos {old_pos_for_log}, referrals {referrer.referrals}) attempting to change position to target {new_position_target} due to referral by {user.id}.")
                                try:
                                    referrer.change_position(new_position_target)
                                    # change_position calls self.refresh_from_db()
                                    if referrer.position != old_pos_for_log:
                                        print(f"[INFO] Referrer {referrer.id} position successfully changed from {old_pos_for_log} to {referrer.position}.")
                                    else:
                                        print(f"[INFO] Referrer {referrer.id} position {referrer.position} did not change (e.g., already optimal or no effective change).")
                                except ValueError as ve:
                                    print(f"[ERROR] ValueError during change_position for referrer {referrer.id}: {str(ve)}")
                                except Exception as e:
                                    print(f"[ERROR] Unexpected error during change_position for referrer {referrer.id}: {str(e)}")
                            
                            # Clear the referral code from the session after processing
                            request.session.pop('referral_code', None)
                            request.session.modified = True # Ensure session changes are saved
                            print(f"[INFO] Cleared referral_code from session for processed referral (referrer: {referrer.id}).")
                        else:
                            print(f"[INFO] New user {user.id} tried to refer themselves using code {referral_code}. No referral processed.")
                            # Still good to clear the code if it was theirs
                            if referrer.id == user.id:
                                request.session.pop('referral_code', None)
                                request.session.modified = True

                    except WaitlistedAppUser.DoesNotExist:
                        print(f"[WARNING] Referrer with code {referral_code} not found. No referral processed for user {user.id}.")
                        request.session.pop('referral_code', None) # Clear invalid code
                        request.session.modified = True
                        pass
                    except Exception as e:
                        print(f"[ERROR] General error processing referral for user {user.id} with referral_code {referral_code}: {str(e)}")
                        # Optionally clear code, or leave for retry if appropriate
                        pass
                # --- END REFERRAL LOGIC ---

            return redirect('user_position', user_id=user.id)
        else:
            context['error_message'] = "Phone number is required."
    
    # Ensure total_waitlisted_users is always in context for GET requests too
    if 'total_waitlisted_users' not in context:
        context['total_waitlisted_users'] = WaitlistedAppUser.objects.count()
    
    return render(request, "waitlist.html", context)

# Consider if CSRF is needed or how to handle it with a SPA-like feel if applicable
def update_school(request, user_id):
    if request.method == 'POST':
        school_name_input = request.POST.get('school_name', '').strip() # Get and strip whitespace
        # The input from the autocomplete might be the ID or the name.
        # For now, let's assume it's the name, and we'll find or create the University.
        # We'll also need a hidden input in the form to store the selected university's ID
        # if the autocomplete directly provides it.
        # Let's adjust this later based on the autocomplete implementation.
        # For now, we'll work with school_name_input.

        try:
            user = WaitlistedAppUser.objects.get(id=user_id)
            current_school_object = user.school # This is now a University object or None

            if school_name_input:
                # Find or create the university
                # We'll use a new field in the form, 'school_id', to submit the ID of an existing University
                # and 'school_name' for potentially creating a new one if not selected from dropdown.
                # However, the request stated "The user can only submit a result that shows up in the dropdown."
                # This implies we should primarily rely on an ID or a confirmed name.
                # Let's assume for now the form will submit `school_id` if a selection is made,
                # and `school_name` will be the textual representation.

                # For this iteration, let's assume the input is the NAME and we must find an EXACT match.
                # The autocomplete view will be responsible for providing valid names.
                try:
                    selected_university = University.objects.get(name__iexact=school_name_input)
                except University.DoesNotExist:
                    # As per "The user can only submit a result that shows up in the dropdown",
                    # we should not create a new one here if it doesn't exist.
                    # This case should ideally be prevented by the frontend.
                    # We can add an error message or handle it gracefully.
                    print(f"[WARNING] Submitted school name '{school_name_input}' not found for user {user_id}. No update made.")
                    return redirect('user_position', user_id=user_id)


                if current_school_object != selected_university:
                    user.school = selected_university
                    user.save(update_fields=['school'])
                    messages.success(request, f'Got it! We bumped you up in the waitlist.')
                    
                    if user.position and user.position > 1: # Check if position is not None
                        print(f"[INFO] School updated for user {user.id}. Attempting to change position from {user.position} to {user.position - 1}")
                        user.change_position(user.position - 1)
                
            elif current_school_object: # If school_name_input is empty and there was a school
                user.school = None 
                user.save(update_fields=['school'])
                messages.success(request, 'School information cleared.')
                # No position change for clearing school

        except WaitlistedAppUser.DoesNotExist:
            print(f"[ERROR] WaitlistedAppUser with id {user_id} not found in update_school.")
            pass 
        except Exception as e:
            print(f"[ERROR] An unexpected error occurred in update_school for user {user_id}: {str(e)}")
            import traceback
            traceback.print_exc()
        
        return redirect('user_position', user_id=user_id)
    
    return redirect('user_position', user_id=user_id)

def update_full_name(request, user_id): # Renamed from update_name
    if request.method == 'POST':
        new_first_name = request.POST.get('user_first_name', '').strip()
        new_last_name = request.POST.get('user_last_name', '').strip()

        try:
            user = WaitlistedAppUser.objects.get(id=user_id)
            
            updated_fields = []
            name_changed = False

            if user.first_name != new_first_name:
                user.first_name = new_first_name
                updated_fields.append('first_name')
                name_changed = True
            
            if user.last_name != new_last_name:
                user.last_name = new_last_name
                updated_fields.append('last_name')
                name_changed = True

            if updated_fields:
                user.save(update_fields=updated_fields)
                if new_first_name or new_last_name:
                    messages.success(request, f'Thanks {new_first_name}! We bumped you up in the waitlist.')
                else:
                    messages.success(request, 'Your name has been cleared.')
                
                # Position change logic only if name was actually changed and user had a name before or has one now
                if name_changed and (user.position and user.position > 1):
                    # Check if the name fields were previously empty and are now filled
                    # This condition might need refinement based on exact requirements for position bumping for initial name entry vs. name change.
                    # For now, any change that results in a non-empty name or a different name bumps position.
                    print(f"[INFO] Name updated for user {user.id}. Attempting to change position from {user.position} to {user.position - 1}")
                    user.change_position(user.position - 1)

        except WaitlistedAppUser.DoesNotExist:
            print(f"[ERROR] WaitlistedAppUser with id {user_id} not found in update_full_name.")
            pass 
        except Exception as e:
            print(f"[ERROR] An unexpected error occurred in update_full_name for user {user_id}: {str(e)}")
            import traceback
            traceback.print_exc()
        
        return redirect('user_position', user_id=user_id)
    
    return redirect('user_position', user_id=user_id)

# New view for university autocomplete
def university_autocomplete(request):
    if 'term' in request.GET:
        term = request.GET.get('term')
        # Search in both name and aliases (assuming aliases is a list of strings)
        # For JSONField, specific query capabilities depend on the database.
        # This __icontains on a JSONField might work if it's stored as a text representation
        # of a list (e.g., in SQLite) or if the DB supports it (e.g. PostgreSQL specific lookups).
        # A more robust solution for JSONField might require iterating over aliases if this doesn't work as expected across all DBs.
        query = Q(name__icontains=term) | Q(aliases__icontains=term)
        universities = University.objects.filter(query).values_list('name', flat=True).distinct()[:10]
        return JsonResponse(list(universities), safe=False)
    return JsonResponse([], safe=False)

def privacy_policy_view(request):
    return render(request, 'privacy.html')

def terms_of_use_view(request):
    return render(request, 'terms_of_use.html')