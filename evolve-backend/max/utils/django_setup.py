import os
import sys
import django
from functools import lru_cache
from pathlib import Path

@lru_cache(maxsize=1)
def ensure():
    """Idempotently configure Django settings for standalone utility modules.

    Many service/utility files are executed outside a typical Django `manage.py`
    context (e.g., invoked directly by the LLM).  Calling this function first
    guarantees that:

    1. `DJANGO_SETTINGS_MODULE` is set.
    2. `django.setup()` has been executed **once and only once** for the
       lifetime of the Python interpreter.
    """
    if "DJANGO_SETTINGS_MODULE" not in os.environ:
        # Compute workspace root by ascending until we find `manage.py`.
        cwd = Path(__file__).resolve()
        for parent in cwd.parents:
            if (parent / "manage.py").exists():
                project_root = parent
                break
        else:
            # Fallback to two levels up from utils/ if manage.py not found.
            project_root = cwd.parent.parent

        sys.path.append(str(project_root))
        os.environ.setdefault("DJANGO_SETTINGS_MODULE", "backend.settings")

    # Django initialisation is safe to call multiple times – guarded by
    # internal flags – but we wrap in lru_cache for clarity.
    django.setup() 