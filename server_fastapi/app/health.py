from __future__ import annotations

import logging
import threading
import time

from .config import settings
from .db import get_connection
from .schemas import HealthResponse
from .version import APP_VERSION

_lock = threading.Lock()
_checked_at = 0.0
_database_ready = False
_database_name = ""


def health_snapshot() -> HealthResponse:
    global _checked_at, _database_ready, _database_name
    # Share a short-lived result across phones to avoid a SQL login per heartbeat.
    with _lock:
        if time.monotonic() - _checked_at >= 10 or _database_name != settings.db_name:
            try:
                connection = get_connection(autocommit=True, timeout=2, login_timeout=2)
                try:
                    cursor = connection.cursor()
                    cursor.execute("SELECT 1")
                    cursor.fetchone()
                    _database_ready = True
                finally:
                    connection.close()
            except Exception:
                _database_ready = False
                logging.getLogger("uvicorn.error").warning("Health check: database unavailable")
            _database_name = settings.db_name
            _checked_at = time.monotonic()
        return HealthResponse(
            status="ok" if _database_ready else "degraded",
            database=settings.db_name,
            version=APP_VERSION,
            databaseReady=_database_ready,
        )
