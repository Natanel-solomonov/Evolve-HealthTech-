"""Fatigue-related domain logic (framework-agnostic).

Currently proxies to the existing `max.fatigue_model` module while we migrate
callers.  All new code should import from `max.core.fatigue` instead of the
historical path.
"""

from .model import (  # noqa: F401 – re-export
    TwoCompartmentFatigueModel,
    FatigueModelConfig,
)

__all__ = [
    "TwoCompartmentFatigueModel",
    "FatigueModelConfig",
] 