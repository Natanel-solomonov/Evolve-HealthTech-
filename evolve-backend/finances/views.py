from django.shortcuts import render
from django.http import HttpRequest
from .revenue_model import RevenueModel # Assuming revenue_model.py is in the same app directory

# Default values for the form, can be adjusted as needed
default_form_values = {
    'total_users': 100000,
    'ad_frequency': 5.0,
    'ad_model_type': 'ecpm',
    'ad_model_value': 2.5,
    'premium_conversion_rate': 0.15,
    'premium_revenue_per_user': 10.0,
    'affiliate_engagement_rate': 0.05,
    'avg_product_value': 30.0,
    'affiliate_commission_rate': 0.10
}

def revenue_modeling_view(request: HttpRequest):
    context = {'values': default_form_values, 'summary': None, 'error': None}

    if request.method == 'POST':
        form_data = request.POST
        current_values = {}
        try:
            # Extract and validate data from POST request
            total_users = int(form_data.get('total_users', default_form_values['total_users']))
            ad_frequency = float(form_data.get('ad_frequency', default_form_values['ad_frequency']))
            ad_model_type = form_data.get('ad_model_type', default_form_values['ad_model_type'])
            ad_model_value = float(form_data.get('ad_model_value', default_form_values['ad_model_value']))
            premium_conversion_rate = float(form_data.get('premium_conversion_rate', default_form_values['premium_conversion_rate']))
            premium_revenue_per_user = float(form_data.get('premium_revenue_per_user', default_form_values['premium_revenue_per_user']))
            affiliate_engagement_rate = float(form_data.get('affiliate_engagement_rate', default_form_values['affiliate_engagement_rate']))
            avg_product_value = float(form_data.get('avg_product_value', default_form_values['avg_product_value']))
            affiliate_commission_rate = float(form_data.get('affiliate_commission_rate', default_form_values['affiliate_commission_rate']))
            
            # Store current form values to repopulate the form
            current_values = {
                'total_users': total_users,
                'ad_frequency': ad_frequency,
                'ad_model_type': ad_model_type,
                'ad_model_value': ad_model_value,
                'premium_conversion_rate': premium_conversion_rate,
                'premium_revenue_per_user': premium_revenue_per_user,
                'affiliate_engagement_rate': affiliate_engagement_rate,
                'avg_product_value': avg_product_value,
                'affiliate_commission_rate': affiliate_commission_rate,
            }
            context['values'] = current_values

            model = RevenueModel(
                total_users=total_users,
                ad_frequency=ad_frequency,
                ad_model_type=ad_model_type,
                ad_model_value=ad_model_value,
                premium_conversion_rate=premium_conversion_rate,
                affiliate_engagement_rate=affiliate_engagement_rate,
                avg_product_value=avg_product_value,
                affiliate_commission_rate=affiliate_commission_rate
            )
            # Update premium revenue per user from form (as it's in init of RevenueModel but also adjustable)
            model.premium_revenue_per_user = premium_revenue_per_user
            model.calculate_revenues() # Recalculate revenues
            
            context['summary'] = model.get_summary()

        except ValueError as e:
            context['error'] = f"Invalid input: {e}. Please ensure all fields are numeric and filled correctly."
        except Exception as e:
            context['error'] = f"An unexpected error occurred: {e}"
            
    return render(request, 'finances/revenue_model_form.html', context)

# Ensure your revenue_model.py RevenueModel class is compatible:
# - It should be importable.
# - Its __init__ method should match the parameters used above.
# - get_summary() should return a string (preferably pre-formatted or easily usable in HTML).
