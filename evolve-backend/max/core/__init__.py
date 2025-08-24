"""Domain logic layer – LLM-agnostic code.

Sub-packages under ``max.core`` must not import from ``max.ai`` or any Django
web modules.  They should remain pure Python so they can be unit-tested without
a database.
"""

from .fatigue import TwoCompartmentFatigueModel, FatigueModelConfig

__all__ = [
    "TwoCompartmentFatigueModel",
    "FatigueModelConfig",
] 