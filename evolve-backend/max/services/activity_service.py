from typing import Dict, Optional, List
import json

# Centralised Django bootstrap
from max.utils.django_setup import ensure as _django_setup

_django_setup()

from api.models import AppUser, Activity, UserScheduledActivity
from fitness.models import Workout, CardioWorkout
from max.ai import GroqClient

def create_activity_for_workout(
    workout_id: str,
    name: Optional[str] = None,
    description: str = "",
    default_point_value: int = 50,
    category: Optional[List[str]] = None,
) -> Dict[str, str]:
    """
    Creates an Activity linked to an existing Workout.
    """
    try:
        workout = Workout.objects.get(id=workout_id)
    except Workout.DoesNotExist:
        return {"error": f"Workout with id {workout_id} not found."}

    activity = Activity.objects.create(
        name=name or workout.name,
        description=description or workout.description,
        default_point_value=default_point_value,
        category=category or ["Fitness"],
        associated_workout=workout,
    )
    return {"activity_id": str(activity.id)}

def schedule_activity(
    user_id: str,
    activity_id: str,
    scheduled_date_iso: str,
    order_in_day: int = 0,
    is_generated: bool = True,
) -> Dict[str, str]:
    """
    Creates a UserScheduledActivity record for a given date (YYYY-MM-DD).
    """
    from datetime import date as _date

    try:
        user = AppUser.objects.get(id=user_id)
        activity = Activity.objects.get(id=activity_id)
        scheduled_date = _date.fromisoformat(scheduled_date_iso)
    except AppUser.DoesNotExist:
        return {"error": f"User {user_id} not found"}
    except Activity.DoesNotExist:
        return {"error": f"Activity {activity_id} not found"}
    except ValueError:
        return {"error": "Invalid scheduled_date_iso format; expected YYYY-MM-DD."}

    usa, _ = UserScheduledActivity.objects.get_or_create(
        user=user,
        activity=activity,
        scheduled_date=scheduled_date,
        order_in_day=order_in_day,
        defaults={"is_generated": is_generated},
    )
    return {"scheduled_activity_id": str(usa.id)}


def generate_activity_description(scheduled_activity_instance: UserScheduledActivity) -> Dict[str, str]:
    """
    Generates an AI-powered summary for a UserScheduledActivity instance and saves it to the generated_description field.
    The summary focuses on what happened in the activity and what its purpose was.
    
    Args:
        scheduled_activity_instance: The UserScheduledActivity instance to generate a summary for
        
    Returns:
        Dict containing either success message and generated summary, or error message
    """
    try:
        # Extract relevant information from the scheduled activity
        activity = scheduled_activity_instance.activity
        user = scheduled_activity_instance.user
        
        # Build context for the AI prompt
        activity_context = {
            "activity_name": activity.name,
            "activity_description": activity.description,
            "activity_type": activity.activity_type,
            "category": activity.category,
            "scheduled_date": scheduled_activity_instance.scheduled_date.isoformat(),
            "scheduled_time": scheduled_activity_instance.scheduled_display_time,
            "user_name": f"{user.first_name} {user.last_name}",
            "is_complete": scheduled_activity_instance.is_complete,
            "custom_notes": scheduled_activity_instance.custom_notes,
        }
        
        # Add workout details if available
        if activity.associated_workout:
            workout = activity.associated_workout
            exercises = []
            for we in workout.workoutexercise_set.all().order_by('order'):
                exercises.append({
                    "name": we.exercise.name,
                    "sets": we.sets,
                    "reps": we.reps,
                    "weight": we.weight,
                })
            activity_context["workout_details"] = {
                "name": workout.name,
                "duration": str(workout.duration) if workout.duration else None,
                "exercises": exercises[:5]  # Limit to first 5 exercises for brevity
            }
        
        # Add reading content details if available
        if activity.associated_reading:
            reading = activity.associated_reading
            activity_context["reading_details"] = {
                "title": reading.title,
                "duration": str(reading.duration) if reading.duration else None,
                "description": reading.description,
            }
        
        # Create AI prompts
        system_prompt = (
            "You are an AI assistant that creates concise summaries of completed user activities. "
            "Your task is to summarize what happened in the activity and what its purpose was. "
            "Keep the summary to 1-2 sentences, around 200-300 characters total. "
            "Focus on the key actions taken and the intended benefit or goal. "
            "Write in a neutral, informative tone - not motivational or encouraging."
        )
        
        user_prompt = (
            f"Please create a brief summary of this activity focusing on what happened and its purpose:\n\n"
            f"{json.dumps(activity_context, indent=2)}\n\n"
            f"Generate a concise summary (200-300 characters) that explains what the user did "
            f"and what the activity was intended to accomplish."
        )
        
        # Call Groq AI to generate the description
        client = GroqClient()
        generated_description = client.send_message(
            user_prompt=user_prompt,
            system_prompt=system_prompt,
            use_tools=False  # We don't need tools for this simple text generation
        )
        
        # Clean up the response (remove any markdown formatting, extra whitespace, etc.)
        generated_description = generated_description.strip()
        
        # Remove common AI response prefixes
        prefixes_to_remove = [
            "Here's a brief summary:",
            "Here's a concise summary:",
            "Here's the summary:",
            "Summary:",
            "Brief summary:",
            "Here's a brief description:",
            "Here's a concise description:",
            "Here's the description:",
            "Description:",
            "Brief description:",
        ]
        
        for prefix in prefixes_to_remove:
            if generated_description.startswith(prefix):
                generated_description = generated_description[len(prefix):].strip()
                break
        
        # Remove quotes if the response is wrapped in them
        if ((generated_description.startswith('"') and generated_description.endswith('"')) or
            (generated_description.startswith("'") and generated_description.endswith("'"))):
            generated_description = generated_description[1:-1].strip()
        
        # Ensure it doesn't end with incomplete formatting
        generated_description = generated_description.rstrip('."')
        
        # Save the generated description to the model
        scheduled_activity_instance.generated_description = generated_description
        scheduled_activity_instance.save(update_fields=['generated_description'])
        
        return {
            "success": True,
            "message": "Activity summary generated successfully",
            "generated_description": generated_description
        }
        
    except Exception as e:
        return {
            "success": False, 
            "error": f"Failed to generate activity summary: {str(e)}"
        }

# ---------------------------------------------------------------------------
# Cardio helpers
# ---------------------------------------------------------------------------

def create_cardio_activity(
    user_id: str,
    cardio_type: str = "run",
    duration_minutes: int | None = None,
    name: str | None = None,
    default_point_value: int = 30,
) -> Dict[str, str]:
    """Convenience wrapper that creates a CardioWorkout and linked Activity.

    Returns a dict with keys ``workout_id`` and ``activity_id``.
    """
    from datetime import timedelta as _td

    cw = CardioWorkout.objects.create(
        name=name or f"{duration_minutes}-Minute {cardio_type.capitalize()}",
        cardio_type=cardio_type,
        duration=_td(minutes=duration_minutes or 30),
        is_treadmill=False,
        is_outdoor=True,
    )

    activity = Activity.objects.create(
        name=cw.name,
        description=f"A {duration_minutes}-minute {cardio_type} session.",
        default_point_value=default_point_value,
        category=["Fitness"],
        associated_workout=None,
        associated_reading=None,
    )

    # No schedule here; caller will schedule_activity.
    return {"workout_id": str(cw.id), "activity_id": str(activity.id)} 