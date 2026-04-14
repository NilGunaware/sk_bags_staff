from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv

from .runtime import env_path


load_dotenv(env_path())


def _env_bool(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    port: int = int(os.getenv("PORT", "8000"))
    db_host: str = os.getenv("DB_HOST", "127.0.0.1")
    db_port: int = int(os.getenv("DB_PORT", "14334"))
    db_user: str = os.getenv("DB_USER", "sa")
    db_password: str = os.getenv("DB_PASSWORD", "")
    db_name: str = os.getenv("DB_NAME", "BusyComp0019_db12026")
    db_timeout: int = int(os.getenv("DB_TIMEOUT", "60"))
    default_page_size: int = int(os.getenv("DEFAULT_PAGE_SIZE", "20"))
    max_page_size: int = int(os.getenv("MAX_PAGE_SIZE", "100"))
    debug: bool = _env_bool("DEBUG", False)


settings = Settings()
