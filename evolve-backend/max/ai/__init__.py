"""AI package housing model clients and related utilities.

Currently acts as a modernised façade over the legacy `max.groq_client` code so
other packages can migrate to `from max.ai import GroqClient` without massive
changes.  Once callers are updated, the old path can be deprecated.
"""

from .client import GroqClient

__all__ = [
    "GroqClient",
] 