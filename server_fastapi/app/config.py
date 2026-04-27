from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import dotenv_values

from .runtime import env_path


def _env_bool(value: str | bool | None, default: bool) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    return value.strip().lower() in {"1", "true", "yes", "on"}


@dataclass
class Settings:
    port: int = 8000
    db_host: str = "127.0.0.1"
    db_port: int = 14334
    db_user: str = "sa"
    db_password: str = ""
    db_name: str = "BusyComp0019_db12026"
    db_timeout: int = 60
    db_startup_timeout: int = 8
    default_page_size: int = 20
    max_page_size: int = 100
    photo_dir: str = "E:/PHOTO"
    debug: bool = False

    def reload(self) -> "Settings":
        file_values = {}
        if env_path().exists():
            file_values = dotenv_values(env_path())

        def get_value(name: str, default: str) -> str:
            value = os.getenv(name)
            if value is not None:
                return value
            file_value = file_values.get(name)
            if file_value is None:
                return default
            return str(file_value)

        self.port = int(get_value("PORT", "8000"))
        self.db_host = get_value("DB_HOST", "127.0.0.1")
        self.db_port = int(get_value("DB_PORT", "14334"))
        self.db_user = get_value("DB_USER", "sa")
        self.db_password = get_value("DB_PASSWORD", "")
        self.db_name = get_value("DB_NAME", "BusyComp0019_db12026")
        self.db_timeout = int(get_value("DB_TIMEOUT", "60"))
        self.db_startup_timeout = int(get_value("DB_STARTUP_TIMEOUT", "8"))
        self.default_page_size = int(get_value("DEFAULT_PAGE_SIZE", "20"))
        self.max_page_size = int(get_value("MAX_PAGE_SIZE", "100"))
        self.photo_dir = get_value("PHOTO_DIR", "E:/PHOTO")
        self.debug = _env_bool(get_value("DEBUG", "false"), False)
        return self

    def has_database_config(self) -> bool:
        return bool(
            str(self.db_host).strip()
            and int(self.db_port) > 0
            and str(self.db_user).strip()
            and str(self.db_name).strip()
        )


settings = Settings().reload()
