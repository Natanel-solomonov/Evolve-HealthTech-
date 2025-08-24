from datetime import date
import json
from typing import List, Dict, Any

from django.db import transaction
from django.utils import timezone

from . import (
    get_user_details,
    get_user_1rm_stats,
    get_user_available_equipment,
    search_exercises,
    create_workout_instance,
    create_activity_for_workout,
    schedule_activity,
    create_cardio_activity,
)
from max.ai import GroqClient


class CustomWorkoutGenerationError(Exception):
    """Raised when the workout generation flow fails for any reason."""


@transaction.atomic
def generate_custom_workout(
    *,
    user_id: str,
    muscle_groups: List[str],
    duration: int = 40,
    intensity: str = "medium",
    include_cardio: bool = False,
    schedule_for_today: bool = True,
) -> Dict[str, Any]:
    """Public helper that implements the same flow as the management command.

    This is safe to use inside a web request because it wraps DB writes in a
    transaction – any exception rolls back partial inserts.
    """

    # ------------------------------------------------------------------
    # Validate inputs early
    # ------------------------------------------------------------------
    if not muscle_groups:
        raise CustomWorkoutGenerationError("At least one target muscle must be specified.")
    if duration not in (20, 40, 60):
        raise CustomWorkoutGenerationError("Duration must be 20, 40, or 60 minutes.")
    if intensity not in ("low", "medium", "high"):
        raise CustomWorkoutGenerationError("Intensity must be one of low/medium/high.")

    target_muscles = [m.strip().lower() for m in muscle_groups if m.strip()]

    # ------------------------------------------------------------------
    # Gather user context
    # ------------------------------------------------------------------
    user_details = get_user_details(user_id)
    if "error" in user_details:
        raise CustomWorkoutGenerationError(user_details["error"])

    one_rm_stats = get_user_1rm_stats(user_id)
    one_rm_lookup = {}
    if isinstance(one_rm_stats, dict) and "one_rep_maxes" in one_rm_stats:
        for item in one_rm_stats["one_rep_maxes"]:
            one_rm_lookup[item["exercise_name"].lower()] = item["one_rep_max"]

    equipment_list = get_user_available_equipment(user_id) or []

    # ------------------------------------------------------------------
    # Build candidate exercise pool
    # ------------------------------------------------------------------
    exer_search_resp = search_exercises(
        primary_muscles=target_muscles,
        equipment=equipment_list,
    )
    if "No exercises found" in exer_search_resp:
        raise CustomWorkoutGenerationError("No exercises matched the requested muscles with the available equipment.")

    # ------------------------------------------------------------------
    # Ask LLM for ordered selection
    # ------------------------------------------------------------------
    desired_ex_count = {20: 4, 40: 6, 60: 8}[duration]
    system_prompt = (
        "You are an elite fitness coach. Select EXACTLY {n} exercises from the list "
        "that collectively target the specified muscles. Prioritise compound lifts first, "
        "avoid redundant variations, and suit the requested intensity ('{intensity}'). "
        "Return ONLY a JSON array of the chosen exercise IDs in execution order.".format(
            n=desired_ex_count, intensity=intensity
        )
    )
    user_prompt = (
        f"Target muscles: {', '.join(target_muscles)}\n"
        f"Workout duration: {duration} minutes\n"
        f"Include cardio: {include_cardio}\n\n"
        f"Available exercises:\n{exer_search_resp}"
    )

    client = GroqClient()
    llm_response_text = client.send_message(
        user_prompt=user_prompt, system_prompt=system_prompt, use_tools=False
    )
    
    # The LLM often returns conversational text around the JSON. We need to extract it.
    import re
    json_str_to_parse = ""
    
    # Try to find all JSON code blocks and take the last one.
    code_block_matches = re.findall(r"```json\s*([\s\S]*?)\s*```", llm_response_text)
    if code_block_matches:
        json_str_to_parse = code_block_matches[-1].strip()
    else:
        # Fallback for raw arrays, also taking the last one found.
        array_matches = re.findall(r"(\[[\s\S]*?\])", llm_response_text)
        if array_matches:
            json_str_to_parse = array_matches[-1].strip()

    if not json_str_to_parse:
        raise CustomWorkoutGenerationError(f"Could not find a valid JSON array in the LLM response.")

    try:
        raw_ids = json.loads(json_str_to_parse)
        if not isinstance(raw_ids, list):
            raise ValueError("LLM did not return a list.")
        import uuid
        selected_ids = []
        for item_id in raw_ids:
            try:
                uuid.UUID(str(item_id))
                selected_ids.append(str(item_id))
            except ValueError:
                # skip non-UUIDs
                continue
    except (json.JSONDecodeError, ValueError) as exc:
        raise CustomWorkoutGenerationError(f"Failed to parse extracted JSON from LLM response: {exc}") from exc

    if len(selected_ids) < 1:
        raise CustomWorkoutGenerationError("LLM did not return any valid exercise IDs.")

    # ------------------------------------------------------------------
    # Construct workout exercises
    # ------------------------------------------------------------------
    from fitness.models import Exercise as _Ex

    exercises_details = []
    for ex_id in selected_ids:
        try:
            ex_obj = _Ex.objects.get(id=ex_id)
        except _Ex.DoesNotExist:
            continue

        r1_val = one_rm_lookup.get(ex_obj.name.lower())
        weight_val = 0
        reps_val = 10
        sets_val = 3
        if r1_val and r1_val > 0:
            pct = {"low": 0.5, "medium": 0.65, "high": 0.75}[intensity]
            weight_val = round(pct * r1_val)
            reps_val = 12 if intensity == "low" else 8
            sets_val = 3 if intensity != "high" else 4

        exercises_details.append(
            {
                "exercise_id": ex_id,
                "sets": sets_val,
                "reps": reps_val,
                "weight": weight_val,
            }
        )

    if not exercises_details:
        raise CustomWorkoutGenerationError("No valid exercises after validation.")

    # ------------------------------------------------------------------
    # Persist workout & linked rows
    # ------------------------------------------------------------------
    wk_resp = create_workout_instance(
        user_id=user_id,
        workout_name="Custom Generated Workout",
        exercises_details=exercises_details,
    )
    workout_id = wk_resp.get("workout_id")
    if not workout_id:
        raise CustomWorkoutGenerationError(wk_resp.get("error", "Workout creation failed."))

    act_resp = create_activity_for_workout(workout_id=workout_id)
    activity_id = act_resp.get("activity_id")
    if not activity_id:
        raise CustomWorkoutGenerationError("Activity creation failed.")

    scheduled_activity_id = None
    if schedule_for_today:
        sched_resp = schedule_activity(
            user_id=user_id,
            activity_id=activity_id,
            scheduled_date_iso=date.today().isoformat(),
        )
        scheduled_activity_id = sched_resp.get("scheduled_activity_id")

    cardio_ids = {}
    if include_cardio:
        cardio_resp = create_cardio_activity(user_id=user_id, cardio_type="run", duration_minutes=10)
        cardio_act_id = cardio_resp.get("activity_id")
        if cardio_act_id and schedule_for_today:
            sched_resp = schedule_activity(
                user_id=user_id,
                activity_id=cardio_act_id,
                scheduled_date_iso=date.today().isoformat(),
                order_in_day=1,
            )
            cardio_ids = {
                "cardio_activity_id": cardio_act_id,
                "cardio_scheduled_id": sched_resp.get("scheduled_activity_id"),
            }

    return {
        "workout_id": workout_id,
        "activity_id": activity_id,
        "scheduled_activity_id": scheduled_activity_id,
        **cardio_ids,
    } 