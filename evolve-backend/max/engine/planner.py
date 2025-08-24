"""Deprecated compatibility shim.

`max.core.workout_planner` now owns the real implementation. Importing from
`max.engine.planner` continues to work but will raise a deprecation warning in
future releases.
"""

from datetime import date
from typing import Dict

from max.services import generate_weekly_schedule as _generate

__all__ = [
    "generate_weekly_plan",
    "generate_weekly_schedule",
]


def generate_weekly_plan(
    user_id: str,
    include_cardio: bool = True,
    active_days: int | None = None,
    start_date: date | None = None,
) -> Dict:
    """Shim forwarding to :pymeth:`max.core.workout_planner.generate_weekly_schedule`."""

    return _generate(
        user_id=user_id,
        include_cardio=include_cardio,
        active_days=active_days,
        start_date=start_date,
    )


# Alias for callers already migrated to the new name.
generate_weekly_schedule = _generate 