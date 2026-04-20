from __future__ import annotations

import socket
from contextlib import contextmanager
from typing import Any, Iterator

import pytds

from .config import settings


def get_connection(
    *,
    autocommit: bool = False,
    timeout: int | None = None,
    login_timeout: int | None = None,
) -> pytds.Connection:
    effective_timeout = timeout if timeout is not None else settings.db_timeout
    effective_login_timeout = login_timeout if login_timeout is not None else settings.db_timeout
    return pytds.connect(
        server=settings.db_host,
        port=settings.db_port,
        database=settings.db_name,
        user=settings.db_user,
        password=settings.db_password,
        timeout=effective_timeout,
        login_timeout=effective_login_timeout,
        autocommit=autocommit,
        use_mars=True,
    )


@contextmanager
def db_connection(*, autocommit: bool = False) -> Iterator[pytds.Connection]:
    connection = get_connection(autocommit=autocommit)
    try:
        yield connection
    finally:
        connection.close()


def rows_to_dicts(cursor: pytds.Cursor) -> list[dict[str, Any]]:
    columns = [column[0] for column in cursor.description or []]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def assert_database_reachable_for_startup() -> None:
    socket_timeout = max(1, min(settings.db_startup_timeout, 5))
    try:
        with socket.create_connection((settings.db_host, settings.db_port), timeout=socket_timeout):
            pass
    except OSError as error:
        raise RuntimeError(
            f"Database server {settings.db_host}:{settings.db_port} is unreachable. "
            "Check that SQL Server is running and the server IP/port are correct."
        ) from error

    try:
        connection = get_connection(
            autocommit=True,
            timeout=settings.db_startup_timeout,
            login_timeout=settings.db_startup_timeout,
        )
        try:
            cursor = connection.cursor()
            cursor.execute("SELECT DB_NAME()")
            cursor.fetchone()
        finally:
            connection.close()
    except Exception as error:
        raise RuntimeError(
            f"Connected to {settings.db_host}:{settings.db_port} but could not open database "
            f"{settings.db_name}. Check the database name, login credentials, and SQL Server permissions."
        ) from error
