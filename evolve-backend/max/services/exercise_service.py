from typing import List, Optional, Tuple, Dict
import json

# Central Django bootstrap
from max.utils.django_setup import ensure as _django_setup

_django_setup()

from fitness.models import Exercise
from functools import lru_cache
from django.db.models import Q, Value, IntegerField, Case, When

def search_exercises(
    level: Optional[str] = None,
    equipment: Optional[List[str]] = None,
    primary_muscles: Optional[List[str]] = None,
    secondary_muscles: Optional[List[str]] = None,
    category: Optional[str] = None,
    force: Optional[str] = None,
    mechanic: Optional[str] = None,
    is_cardio: Optional[bool] = None
) -> str:
    """
    Searches for exercises based on specified criteria.
    Returns a string containing the details of matching exercises.
    """
    try:
        cache_key = json.dumps([
            level, equipment, primary_muscles, secondary_muscles, category, force, mechanic, is_cardio
        ], sort_keys=True)

        @lru_cache(maxsize=128)
        def _cached_search(_key: str):
            qset = Exercise.search_exercises(
                level=level,
                equipment=equipment,
                primary_muscles=primary_muscles,
                secondary_muscles=secondary_muscles,
                category=category
            )

            if force is not None:
                qset = qset.filter(force__iexact=force)
            if mechanic is not None:
                qset = qset.filter(mechanic__iexact=mechanic)
            if is_cardio is not None:
                qset = qset.filter(isCardio=is_cardio)

            # Relevance ordering
            ordering_expr = Case(
                When(level=level, then=Value(0)),  # exact level match highest
                default=Value(1),
                output_field=IntegerField(),
            ) if level else Value(1)

            qset = qset.annotate(level_rank=ordering_expr).order_by('level_rank', 'name')
            return list(qset.values("id", "name", "level", "equipment", "primary_muscles"))

        result_values = _cached_search(cache_key)
        exercises = [Exercise.objects.get(id=val["id"]) for val in result_values]

        if not exercises:
            return "No exercises found matching your criteria."

        output_parts = [f"Found {len(exercises)} exercises:"]
        for i, exercise in enumerate(exercises):
            details = [
                f"--- Exercise {i+1} ---",
                f"  ID: {exercise.id}",
                f"  Name: {exercise.name}",
                f"  Level: {exercise.level}",
                f"  Equipment: {exercise.equipment or 'None'}",
                f"  Primary Muscles: {', '.join(exercise.primary_muscles or [])}",
            ]
            output_parts.extend(details)
        
        return "\n".join(output_parts)

    except Exception as e:
        return f"An error occurred while searching for exercises: {str(e)}"

# ---------------------------------------------------------------------------
# Internal cache
# ---------------------------------------------------------------------------

@lru_cache(maxsize=256)
def _cached_query(key: Tuple[str, str]) -> List[Dict]:
    """Cache wrapper returning list of exercise info dicts for given raw SQL."""
    sql, params_json = key
    # simplistic: execute ORM filter again; caching bigger agility
    return [] 