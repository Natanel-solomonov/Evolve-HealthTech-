import argparse

class RevenueModel:
    def __init__(self, total_users, ad_frequency, ad_model_type, ad_model_value,
                 premium_conversion_rate, affiliate_engagement_rate,
                 avg_product_value, affiliate_commission_rate):
        self.total_users = total_users
        self.ad_frequency = ad_frequency  # Ads per user per day (or other period)
        self.ad_model_type = ad_model_type  # 'ecpm' or 'rpm'
        self.ad_model_value = ad_model_value  # e.g., $5 for eCPM, $0.01 for RPM
        self.premium_conversion_rate = premium_conversion_rate  # e.g., 0.2 for 20%
        self.affiliate_engagement_rate = affiliate_engagement_rate  # e.g., 0.1 for 10%
        self.avg_product_value = avg_product_value  # e.g., $50
        self.affiliate_commission_rate = affiliate_commission_rate  # e.g., 0.1 for 10%

        self.non_premium_users = 0
        self.ad_impressions = 0
        self.ad_revenue = 0
        self.premium_subscribers = 0
        self.premium_revenue_per_user = 10 # Placeholder: assuming $10/month per premium user
        self.premium_revenue = 0
        self.affiliate_users = 0
        self.affiliate_revenue = 0
        self.total_revenue = 0

        self.calculate_revenues()

    def calculate_ad_revenue(self):
        """Calculates revenue from interstitial ads."""
        self.non_premium_users = self.total_users * (1 - self.premium_conversion_rate)
        self.ad_impressions = self.non_premium_users * self.ad_frequency

        if self.ad_model_type.lower() == 'ecpm':
            # eCPM is cost per 1000 impressions
            self.ad_revenue = (self.ad_impressions / 1000) * self.ad_model_value
        elif self.ad_model_type.lower() == 'rpm':
            # RPM is revenue per 1000 impressions (often used interchangeably with eCPM in some contexts)
            # Or, if it means Revenue Per Mille (per thousand users), the calculation might differ.
            # For this model, we'll assume RPM here means revenue per impression directly for simplicity,
            # as eCPM already covers per-mille impressions.
            # If RPM means revenue per user, the formula would be:
            # self.ad_revenue = self.non_premium_users * self.ad_model_value
            # For now, let's assume RPM is revenue per single impression if not eCPM.
            # User prompt mentioned "RPM including different values for each" implying it could be a direct rate.
            # To avoid ambiguity, we will consider RPM as Revenue Per Mille for now.
            self.ad_revenue = (self.ad_impressions / 1000) * self.ad_model_value
        else:
            self.ad_revenue = 0
            print(f"Warning: Unknown ad model type '{self.ad_model_type}'. Ad revenue will be 0.")
        return self.ad_revenue

    def calculate_premium_revenue(self):
        """Calculates revenue from premium subscriptions."""
        self.premium_subscribers = self.total_users * self.premium_conversion_rate
        # Assuming a fixed monthly price for premium, e.g., $10/month
        # This should ideally be another input parameter if it can vary.
        self.premium_revenue = self.premium_subscribers * self.premium_revenue_per_user
        return self.premium_revenue

    def calculate_affiliate_revenue(self):
        """Calculates revenue from affiliate marketing."""
        self.affiliate_users = self.total_users * self.affiliate_engagement_rate
        # Revenue is per engaged user, based on avg product value and commission
        revenue_per_affiliate_user_action = self.avg_product_value * self.affiliate_commission_rate
        # Assuming one action per engaged user for simplicity
        self.affiliate_revenue = self.affiliate_users * revenue_per_affiliate_user_action
        return self.affiliate_revenue

    def calculate_total_revenue(self):
        """Calculates the total revenue from all sources."""
        self.total_revenue = self.ad_revenue + self.premium_revenue + self.affiliate_revenue
        return self.total_revenue

    def calculate_revenues(self):
        """Calculates all revenue streams and the total revenue."""
        self.calculate_ad_revenue()
        self.calculate_premium_revenue()
        self.calculate_affiliate_revenue()
        self.calculate_total_revenue()

    def get_summary(self):
        """Returns a summary of the revenue calculations."""
        summary = f"""
Financial Model Summary:
--------------------------
Total Users: {self.total_users:,.0f}

Interstitial Ad Revenue:
  Non-Premium Users (eligible for ads): {self.non_premium_users:,.0f}
  Ad Frequency (per user): {self.ad_frequency}
  Ad Model: {self.ad_model_type.upper()}
  Ad Model Value: ${self.ad_model_value:,.2f}
  Total Ad Impressions: {self.ad_impressions:,.0f}
  Ad Revenue: ${self.ad_revenue:,.2f}

Premium Subscription Revenue:
  Premium Conversion Rate: {self.premium_conversion_rate:.2%}
  Premium Subscribers: {self.premium_subscribers:,.0f}
  Revenue per Premium User: ${self.premium_revenue_per_user:,.2f} (monthly assumption)
  Premium Revenue: ${self.premium_revenue:,.2f}

Affiliate Marketing Revenue:
  Affiliate Engagement Rate: {self.affiliate_engagement_rate:.2%}
  Users Engaging with Affiliate Offers: {self.affiliate_users:,.0f}
  Average Product Value: ${self.avg_product_value:,.2f}
  Affiliate Commission Rate: {self.affiliate_commission_rate:.2%}
  Affiliate Revenue: ${self.affiliate_revenue:,.2f}

--------------------------
Total Estimated Revenue: ${self.total_revenue:,.2f}
--------------------------
        """
        return summary

def main():
    parser = argparse.ArgumentParser(description="Financial modeling for app revenues.")
    parser.add_argument("--total_users", type=int, required=True, help="Total number of users.")
    parser.add_argument("--ad_frequency", type=float, required=True, help="Number of ads shown per user (e.g., per day).")
    parser.add_argument("--ad_model_type", type=str, choices=['ecpm', 'rpm'], required=True, help="Ad revenue model type: 'ecpm' or 'rpm'.")
    parser.add_argument("--ad_model_value", type=float, required=True, help="Value for the ad model (e.g., eCPM rate, RPM rate).")
    parser.add_argument("--premium_conversion_rate", type=float, required=True, help="Conversion rate to premium subscription (e.g., 0.1 for 10%%).")
    parser.add_argument("--premium_revenue_per_user", type=float, default=10.0, help="Monthly revenue per premium user (default: $10.0).")
    parser.add_argument("--affiliate_engagement_rate", type=float, required=True, help="Percentage of users engaging with affiliate offers (e.g., 0.05 for 5%%).")
    parser.add_argument("--avg_product_value", type=float, required=True, help="Average value of products in affiliate offers.")
    parser.add_argument("--affiliate_commission_rate", type=float, required=True, help="Commission rate from affiliate marketing (e.g., 0.1 for 10%%).")

    args = parser.parse_args()

    model = RevenueModel(
        total_users=args.total_users,
        ad_frequency=args.ad_frequency,
        ad_model_type=args.ad_model_type,
        ad_model_value=args.ad_model_value,
        premium_conversion_rate=args.premium_conversion_rate,
        affiliate_engagement_rate=args.affiliate_engagement_rate,
        avg_product_value=args.avg_product_value,
        affiliate_commission_rate=args.affiliate_commission_rate
    )
    # Override the default premium_revenue_per_user if provided via CLI
    model.premium_revenue_per_user = args.premium_revenue_per_user
    model.calculate_revenues() # Recalculate with potentially updated premium_revenue_per_user

    print(model.get_summary())

if __name__ == "__main__":
    main() 