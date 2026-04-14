from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Any

from .db import db_connection, rows_to_dicts


ITEM_BASE_CTE = """
WITH FolioAgg AS (
    SELECT
        MasterCode,
        SUM(CAST(ISNULL(D1, 0) AS DECIMAL(18, 2))) AS itemQuantity,
        SUM(CAST(ISNULL(D3, 0) AS DECIMAL(18, 2))) AS itemQuantityValue
    FROM dbo.Folio1
    GROUP BY MasterCode
),
MasterSupportAgg AS (
    SELECT
        MasterCode,
        MAX(CASE WHEN NULLIF(C1, '') IS NOT NULL THEN C1 END) AS supportItemCode,
        MAX(CASE WHEN D3 > 0 THEN CAST(D3 AS DECIMAL(18, 2)) END) AS sellingRateHint,
        MAX(CASE WHEN D1 > 0 THEN CAST(D1 AS DECIMAL(18, 2)) END) AS costRateHint
    FROM dbo.MasterSupport
    WHERE MasterType = 6
    GROUP BY MasterCode
),
ItemBase AS (
    SELECT
        m.Code AS itemMasterCode,
        CAST(COALESCE(NULLIF(m.Alias, ''), msa.supportItemCode, CAST(m.Code AS NVARCHAR(50))) AS NVARCHAR(50)) AS itemCode,
        CAST(NULL AS NVARCHAR(100)) AS qrCode,
        m.Name AS itemName,
        COALESCE(pg.Name, '') AS itemGroup,
        COALESCE(fa.itemQuantity, 0) AS itemQuantity,
        COALESCE(fa.itemQuantityValue, 0) AS itemQuantityValue,
        COALESCE(m.HSNCode, '') AS hsnCode,
        msa.sellingRateHint AS sellingRateHint,
        msa.costRateHint AS costRateHint
    FROM dbo.Master1 m
    LEFT JOIN dbo.Master1 pg
        ON pg.Code = m.ParentGrp
    LEFT JOIN FolioAgg fa
        ON fa.MasterCode = m.Code
    LEFT JOIN MasterSupportAgg msa
        ON msa.MasterCode = m.Code
    WHERE m.MasterType = 6
)
"""


ENSURE_ORDER_SCHEMA_SQL = """
IF OBJECT_ID('dbo.ApiOrders', 'U') IS NULL
BEGIN
  CREATE TABLE dbo.ApiOrders (
    id INT IDENTITY(1,1) PRIMARY KEY,
    order_no NVARCHAR(50) NOT NULL UNIQUE,
    order_date DATE NOT NULL,
    series_code NVARCHAR(50) NULL,
    party_name NVARCHAR(255) NOT NULL,
    party_master_code INT NULL,
    total_items INT NOT NULL DEFAULT 0,
    total_quantity DECIMAL(18,2) NOT NULL DEFAULT 0,
    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
  );
END;

IF OBJECT_ID('dbo.ApiOrderItems', 'U') IS NULL
BEGIN
  CREATE TABLE dbo.ApiOrderItems (
    id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT NOT NULL,
    line_no INT NOT NULL,
    item_master_code INT NULL,
    item_code NVARCHAR(100) NULL,
    qr_code NVARCHAR(100) NULL,
    item_name NVARCHAR(255) NOT NULL,
    quantity DECIMAL(18,2) NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ApiOrderItems_ApiOrders
      FOREIGN KEY (order_id) REFERENCES dbo.ApiOrders(id) ON DELETE CASCADE
  );
END;

IF NOT EXISTS (
  SELECT 1
  FROM sys.indexes
  WHERE name = 'IX_ApiOrders_order_date'
    AND object_id = OBJECT_ID('dbo.ApiOrders')
)
BEGIN
  CREATE INDEX IX_ApiOrders_order_date
  ON dbo.ApiOrders(order_date DESC, id DESC);
END;

IF NOT EXISTS (
  SELECT 1
  FROM sys.indexes
  WHERE name = 'IX_ApiOrders_party_name'
    AND object_id = OBJECT_ID('dbo.ApiOrders')
)
BEGIN
  CREATE INDEX IX_ApiOrders_party_name
  ON dbo.ApiOrders(party_name);
END;

IF NOT EXISTS (
  SELECT 1
  FROM sys.indexes
  WHERE name = 'IX_ApiOrderItems_order_id'
    AND object_id = OBJECT_ID('dbo.ApiOrderItems')
)
BEGIN
  CREATE INDEX IX_ApiOrderItems_order_id
  ON dbo.ApiOrderItems(order_id, line_no);
END;

IF NOT EXISTS (
  SELECT 1
  FROM sys.indexes
  WHERE name = 'IX_ApiOrderItems_item_code'
    AND object_id = OBJECT_ID('dbo.ApiOrderItems')
)
BEGIN
  CREATE INDEX IX_ApiOrderItems_item_code
  ON dbo.ApiOrderItems(item_code);
END;
"""


def _like_pattern(value: str | None) -> str:
    text = (value or "").strip()
    return "%" if not text else f"%{text}%"


def _serialize(value: Any) -> Any:
    if isinstance(value, Decimal):
        return float(value)
    return value


def _serialize_row(row: dict[str, Any]) -> dict[str, Any]:
    return {key: _serialize(value) for key, value in row.items()}


def ensure_order_schema() -> None:
    with db_connection() as connection:
        cursor = connection.cursor()
        cursor.execute(ENSURE_ORDER_SCHEMA_SQL)
        connection.commit()


def list_items(*, item_code: str, item_name: str, qr_code: str, offset: int, page_size: int) -> dict[str, Any]:
    if (qr_code or "").strip():
        return {"items": [], "totalCount": 0, "qrCodeAvailable": False}

    params = {
        "item_code_pattern": _like_pattern(item_code),
        "item_name_pattern": _like_pattern(item_name),
        "offset": offset,
        "page_size": page_size,
    }

    count_sql = f"""
    {ITEM_BASE_CTE}
    SELECT COUNT(*) AS totalCount
    FROM ItemBase
    WHERE itemCode LIKE %(item_code_pattern)s
      AND itemName LIKE %(item_name_pattern)s;
    """

    data_sql = f"""
    {ITEM_BASE_CTE}
    SELECT
        itemMasterCode,
        itemCode,
        qrCode,
        itemName,
        itemGroup,
        itemQuantity,
        itemQuantityValue,
        hsnCode,
        sellingRateHint,
        costRateHint
    FROM ItemBase
    WHERE itemCode LIKE %(item_code_pattern)s
      AND itemName LIKE %(item_name_pattern)s
    ORDER BY itemName ASC, itemMasterCode ASC
    OFFSET %(offset)s ROWS FETCH NEXT %(page_size)s ROWS ONLY;
    """

    with db_connection(autocommit=True) as connection:
        cursor = connection.cursor()
        cursor.execute(count_sql, params)
        total_count = int(cursor.fetchone()[0])
        cursor.execute(data_sql, params)
        items = [_serialize_row(row) for row in rows_to_dicts(cursor)]

    return {"items": items, "totalCount": total_count, "qrCodeAvailable": False}


def find_item_reference(
    *,
    item_master_code: int | None,
    item_code: str | None,
    item_name: str | None,
    cursor: Any | None = None,
) -> dict[str, Any] | None:
    owns_connection = cursor is None
    connection = None
    if owns_connection:
        connection = db_connection(autocommit=True).__enter__()
        cursor = connection.cursor()

    try:
        sql = """
        WITH MasterSupportAgg AS (
            SELECT
                MasterCode,
                MAX(CASE WHEN NULLIF(C1, '') IS NOT NULL THEN C1 END) AS supportItemCode
            FROM dbo.MasterSupport
            WHERE MasterType = 6
            GROUP BY MasterCode
        )
        SELECT TOP 1
            m.Code AS itemMasterCode,
            CAST(COALESCE(NULLIF(m.Alias, ''), msa.supportItemCode, CAST(m.Code AS NVARCHAR(50))) AS NVARCHAR(50)) AS itemCode,
            CAST(NULL AS NVARCHAR(100)) AS qrCode,
            m.Name AS itemName
        FROM dbo.Master1 m
        LEFT JOIN MasterSupportAgg msa
            ON msa.MasterCode = m.Code
        WHERE m.MasterType = 6
          AND (
            (%(item_master_code)s IS NOT NULL AND m.Code = %(item_master_code)s)
            OR (
                %(item_code)s <> ''
                AND (
                    m.Alias = %(item_code)s
                    OR msa.supportItemCode = %(item_code)s
                    OR CAST(m.Code AS NVARCHAR(50)) = %(item_code)s
                )
            )
            OR (%(item_name)s <> '' AND m.Name = %(item_name)s)
          )
        ORDER BY m.Code ASC;
        """

        cursor.execute(
            sql,
            {
                "item_master_code": item_master_code,
                "item_code": (item_code or "").strip(),
                "item_name": (item_name or "").strip(),
            },
        )
        row = cursor.fetchone()
        if not row or not cursor.description:
            return None
        return _serialize_row(dict(zip([column[0] for column in cursor.description], row)))
    finally:
        if owns_connection and connection is not None:
            connection.close()


def _normalize_order_date(value: date | None) -> date:
    return value or date.today()


def _build_order_no(order_date: date, order_id: int) -> str:
    return f"SO-{str(order_date.year)[2:]}-{order_id:05d}"


def _resolve_party_master_code(cursor: Any, party_name: str) -> int | None:
    cursor.execute(
        """
        SELECT TOP 1 Code
        FROM dbo.Master1
        WHERE MasterType = 2
          AND Name = %(party_name)s
        ORDER BY Code ASC;
        """,
        {"party_name": party_name},
    )
    row = cursor.fetchone()
    return int(row[0]) if row else None


def create_order(payload: dict[str, Any]) -> dict[str, Any]:
    ensure_order_schema()

    party_name = str(payload.get("partyName") or "").strip()
    series_code = str(payload.get("seriesCode") or "").strip() or None
    order_date = _normalize_order_date(payload.get("orderDate"))
    items = payload.get("items") or []

    if not party_name:
        raise ValueError("partyName is required.")

    if not isinstance(items, list) or not items:
        raise ValueError("At least one order item is required.")

    with db_connection() as connection:
        cursor = connection.cursor()

        resolved_items: list[dict[str, Any]] = []
        for index, item in enumerate(items, start=1):
            quantity = float(item.get("quantity", 0))
            if quantity <= 0:
                raise ValueError(f"Item at line {index} has an invalid quantity.")

            resolved = find_item_reference(
                item_master_code=item.get("itemMasterCode"),
                item_code=item.get("itemCode"),
                item_name=item.get("itemName"),
                cursor=cursor,
            )
            if not resolved:
                raise ValueError(f"Item at line {index} could not be resolved from the database.")

            resolved_items.append(
                {
                    "lineNo": index,
                    "itemMasterCode": resolved["itemMasterCode"],
                    "itemCode": resolved.get("itemCode"),
                    "qrCode": resolved.get("qrCode"),
                    "itemName": resolved["itemName"],
                    "quantity": quantity,
                }
            )

        total_quantity = sum(item["quantity"] for item in resolved_items)
        party_master_code = _resolve_party_master_code(cursor, party_name)

        try:
            cursor.execute(
                """
                INSERT INTO dbo.ApiOrders (
                    order_no,
                    order_date,
                    series_code,
                    party_name,
                    party_master_code,
                    total_items,
                    total_quantity
                )
                OUTPUT INSERTED.id
                VALUES (
                    'PENDING',
                    %(order_date)s,
                    %(series_code)s,
                    %(party_name)s,
                    %(party_master_code)s,
                    %(total_items)s,
                    %(total_quantity)s
                );
                """,
                {
                    "order_date": order_date,
                    "series_code": series_code,
                    "party_name": party_name,
                    "party_master_code": party_master_code,
                    "total_items": len(resolved_items),
                    "total_quantity": total_quantity,
                },
            )
            order_id = int(cursor.fetchone()[0])
            order_no = _build_order_no(order_date, order_id)

            cursor.execute(
                """
                UPDATE dbo.ApiOrders
                SET order_no = %(order_no)s,
                    updated_at = SYSUTCDATETIME()
                WHERE id = %(id)s;
                """,
                {"order_no": order_no, "id": order_id},
            )

            for item in resolved_items:
                cursor.execute(
                    """
                    INSERT INTO dbo.ApiOrderItems (
                        order_id,
                        line_no,
                        item_master_code,
                        item_code,
                        qr_code,
                        item_name,
                        quantity
                    )
                    VALUES (
                        %(order_id)s,
                        %(line_no)s,
                        %(item_master_code)s,
                        %(item_code)s,
                        %(qr_code)s,
                        %(item_name)s,
                        %(quantity)s
                    );
                    """,
                    {
                        "order_id": order_id,
                        "line_no": item["lineNo"],
                        "item_master_code": item["itemMasterCode"],
                        "item_code": item["itemCode"],
                        "qr_code": item["qrCode"],
                        "item_name": item["itemName"],
                        "quantity": item["quantity"],
                    },
                )

            connection.commit()
        except Exception:
            connection.rollback()
            raise

    return get_order_detail(
        order_id,
        item_code="",
        item_name="",
        offset=0,
        page_size=max(len(resolved_items), 1),
    )


def list_orders(
    *,
    order_no: str,
    series_code: str,
    party_name: str,
    item_code: str,
    item_name: str,
    from_date: date | None,
    to_date: date | None,
    offset: int,
    page_size: int,
) -> dict[str, Any]:
    ensure_order_schema()

    params = {
        "order_no_pattern": _like_pattern(order_no),
        "series_code_pattern": _like_pattern(series_code),
        "party_name_pattern": _like_pattern(party_name),
        "item_code_pattern": _like_pattern(item_code),
        "item_name_pattern": _like_pattern(item_name),
        "has_item_filter": 1 if (item_code or item_name) else 0,
        "from_date": from_date,
        "to_date": to_date,
        "offset": offset,
        "page_size": page_size,
    }

    base_where = """
    FROM dbo.ApiOrders o
    WHERE o.order_no LIKE %(order_no_pattern)s
      AND ISNULL(o.series_code, '') LIKE %(series_code_pattern)s
      AND o.party_name LIKE %(party_name_pattern)s
      AND (%(from_date)s IS NULL OR o.order_date >= %(from_date)s)
      AND (%(to_date)s IS NULL OR o.order_date <= %(to_date)s)
      AND (
        %(has_item_filter)s = 0
        OR EXISTS (
            SELECT 1
            FROM dbo.ApiOrderItems oi
            WHERE oi.order_id = o.id
              AND ISNULL(oi.item_code, '') LIKE %(item_code_pattern)s
              AND oi.item_name LIKE %(item_name_pattern)s
        )
      )
    """

    count_sql = f"SELECT COUNT(*) AS totalCount {base_where};"
    data_sql = f"""
    SELECT
        o.id AS id,
        o.order_no AS orderNo,
        o.order_date AS orderDate,
        o.series_code AS seriesCode,
        o.party_name AS partyName,
        o.party_master_code AS partyMasterCode,
        o.total_items AS totalItems,
        o.total_quantity AS totalQuantity,
        o.created_at AS createdAt,
        o.updated_at AS updatedAt
    {base_where}
    ORDER BY o.order_date DESC, o.id DESC
    OFFSET %(offset)s ROWS FETCH NEXT %(page_size)s ROWS ONLY;
    """

    with db_connection(autocommit=True) as connection:
        cursor = connection.cursor()
        cursor.execute(count_sql, params)
        total_count = int(cursor.fetchone()[0])
        cursor.execute(data_sql, params)
        orders = [_serialize_row(row) for row in rows_to_dicts(cursor)]

    return {"orders": orders, "totalCount": total_count}


def get_order_detail(
    order_id: int,
    *,
    item_code: str,
    item_name: str,
    offset: int,
    page_size: int,
) -> dict[str, Any] | None:
    ensure_order_schema()

    item_params = {
        "id": order_id,
        "item_code_pattern": _like_pattern(item_code),
        "item_name_pattern": _like_pattern(item_name),
        "offset": offset,
        "page_size": page_size,
    }

    with db_connection(autocommit=True) as connection:
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT
                id AS id,
                order_no AS orderNo,
                order_date AS orderDate,
                series_code AS seriesCode,
                party_name AS partyName,
                party_master_code AS partyMasterCode,
                total_items AS totalItems,
                total_quantity AS totalQuantity,
                created_at AS createdAt,
                updated_at AS updatedAt
            FROM dbo.ApiOrders
            WHERE id = %(id)s;
            """,
            {"id": order_id},
        )
        header_rows = rows_to_dicts(cursor)
        if not header_rows:
            return None

        cursor.execute(
            """
            SELECT COUNT(*) AS totalCount
            FROM dbo.ApiOrderItems
            WHERE order_id = %(id)s
              AND ISNULL(item_code, '') LIKE %(item_code_pattern)s
              AND item_name LIKE %(item_name_pattern)s;
            """,
            item_params,
        )
        item_total_count = int(cursor.fetchone()[0])

        cursor.execute(
            """
            SELECT
                id,
                line_no,
                item_master_code,
                item_code,
                qr_code,
                item_name,
                quantity,
                created_at
            FROM dbo.ApiOrderItems
            WHERE order_id = %(id)s
              AND ISNULL(item_code, '') LIKE %(item_code_pattern)s
              AND item_name LIKE %(item_name_pattern)s
            ORDER BY line_no ASC
            OFFSET %(offset)s ROWS FETCH NEXT %(page_size)s ROWS ONLY;
            """,
            item_params,
        )

        order = _serialize_row(header_rows[0])
        order["itemTotalCount"] = item_total_count
        order["items"] = [
            {
                "id": _serialize(row["id"]),
                "lineNo": _serialize(row["line_no"]),
                "itemMasterCode": _serialize(row["item_master_code"]),
                "itemCode": _serialize(row["item_code"]),
                "qrCode": _serialize(row["qr_code"]),
                "itemName": _serialize(row["item_name"]),
                "quantity": _serialize(row["quantity"]),
                "createdAt": _serialize(row["created_at"]),
            }
            for row in rows_to_dicts(cursor)
        ]
        return order
