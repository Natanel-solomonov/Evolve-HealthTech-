import os
import django
from datetime import timedelta
from typing import Dict, List

# --- Django Setup ---
if "DJANGO_SETTINGS_MODULE" not in os.environ:
    project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.sys.path.append(project_root)
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
    django.setup()
# --- End Django Setup ---

from api.models import AppUser
from fitness.models import Exercise, Workout, WorkoutExercise

def create_workout_instance(
    user_id: str,
    workout_name: str,
    exercises_details: List[Dict]
) -> Dict[str, str]:
    """
    Creates a `Workout` and associated `WorkoutExercise` rows.
    """
    try:
        _ = AppUser.objects.get(id=user_id)
    except AppUser.DoesNotExist:
        return {"error": f"AppUser with ID '{user_id}' not found."}

    if not exercises_details:
        return {"error": "`exercises_details` cannot be empty."}

    workout = Workout.objects.create(name=workout_name)

    for idx, ex in enumerate(exercises_details, start=1):
        exercise_obj = None
        ex_id = ex.get("exercise_id")
        ex_name = ex.get("exercise_name")
        try:
            if ex_id:
                exercise_obj = Exercise.objects.get(id=ex_id)
            elif ex_name:
                exercise_obj = Exercise.objects.get(name__iexact=ex_name)
            else:
                return {"error": f"Exercise resolution failed. Provide 'exercise_id' or 'exercise_name'."}
        except Exercise.DoesNotExist:
            return {"error": f"Exercise not found (id={ex_id}, name={ex_name})."}

        sets = int(ex.get("sets", 0))
        reps = int(ex.get("reps", 0))
        weight = ex.get("weight")
        if sets <= 0 or reps <= 0 or weight is None:
            return {"error": f"Invalid sets/reps/weight for exercise '{exercise_obj.name}'."}

        WorkoutExercise.objects.create(
            workout=workout,
            exercise=exercise_obj,
            sets=sets,
            reps=reps,
            weight=weight,
            equipment=ex.get("equipment"),
            order=ex.get("order", idx),
            time=timedelta(seconds=ex.get("time", 0)) if ex.get("time") else None,
        )

    return {"workout_id": str(workout.id)} 