from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator

import pytds

from .config import settings


def get_connection(*, autocommit: bool = False) -> pytds.Connection:
    return pytds.connect(
        server=settings.db_host,
        port=settings.db_port,
        database=settings.db_name,
        user=settings.db_user,
        password=settings.db_password,
        timeout=settings.db_timeout,
        login_timeout=settings.db_timeout,
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
