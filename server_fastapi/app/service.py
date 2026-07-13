from __future__ import annotations

from datetime import date
from decimal import Decimal
import mimetypes
from pathlib import Path
from typing import Any
from urllib.parse import quote

from .config import settings
from .db import db_connection, rows_to_dicts


ITEM_BASE_CTE = """
WITH StockAgg AS (
    SELECT
        t.MasterCode1 AS MasterCode,
        SUM(CAST(ISNULL(t.D1, 0) AS DECIMAL(18, 2))) AS itemQuantity,
        SUM(CAST(ISNULL(t.D3, 0) AS DECIMAL(18, 2))) AS itemQuantityValue
    FROM dbo.Tran4 t
    INNER JOIN dbo.Tran1 v
        ON v.VchCode = t.VchCode
    WHERE t.RecType = 0
      AND CAST(v.[Date] AS DATE) <= CAST(GETDATE() AS DATE)
    GROUP BY t.MasterCode1
),
PriceAgg AS (
    SELECT
        MasterCode,
        COUNT(CASE WHEN I1 BETWEEN 101 AND 126 AND ISNULL(D1, 0) > 0 THEN 1 END) AS priceCount,
        MIN(CASE WHEN I1 BETWEEN 101 AND 126 AND ISNULL(D1, 0) > 0
            THEN CAST(D1 - ((D1 * ISNULL(D2, 0)) / 100.0) AS DECIMAL(18, 2)) END) AS minFinalPrice,
        MAX(CASE WHEN I1 BETWEEN 101 AND 126 AND ISNULL(D1, 0) > 0
            THEN CAST(D1 - ((D1 * ISNULL(D2, 0)) / 100.0) AS DECIMAL(18, 2)) END) AS maxFinalPrice
    FROM dbo.MasterSupport
    WHERE MasterType = 6
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
        COALESCE(sa.itemQuantity, 0) AS itemQuantity,
        COALESCE(sa.itemQuantityValue, 0) AS itemQuantityValue,
        COALESCE(m.HSNCode, '') AS hsnCode,
        msa.sellingRateHint AS sellingRateHint,
        msa.costRateHint AS costRateHint,
        COALESCE(pa.priceCount, 0) AS priceCount,
        pa.minFinalPrice AS minFinalPrice,
        pa.maxFinalPrice AS maxFinalPrice
    FROM dbo.Master1 m
    LEFT JOIN dbo.Master1 pg
        ON pg.Code = m.ParentGrp
    LEFT JOIN StockAgg sa
        ON sa.MasterCode = m.Code
    LEFT JOIN MasterSupportAgg msa
        ON msa.MasterCode = m.Code
    LEFT JOIN PriceAgg pa
        ON pa.MasterCode = m.Code
    WHERE m.MasterType = 6
)
"""


PRICE_SLOT_MIN = 101
PRICE_SLOT_MAX = 126
REFERENCE_SLOT_ID = 301
PREFERRED_IMAGE_EXTENSIONS = {
    ".png",
    ".apng",
    ".jpg",
    ".jpeg",
    ".jpe",
    ".jfif",
    ".pjpeg",
    ".pjp",
    ".gif",
    ".bmp",
    ".dib",
    ".webp",
    ".avif",
    ".svg",
    ".svgz",
    ".ico",
    ".tif",
    ".tiff",
    ".heic",
    ".heif",
}

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


def _clean_text(value: Any) -> str:
    return str(value or "").strip()


def _slot_to_category(slot_id: int) -> tuple[int, str]:
    category_no = max(slot_id - 100, 0)
    if 1 <= category_no <= 26:
        return category_no, chr(64 + category_no)
    return category_no, str(category_no)


def _compute_final_price(base_price: float, discount_percent: float) -> float:
    return round(base_price - ((base_price * discount_percent) / 100.0), 2)


def _image_candidates(item_code: str, support_codes: list[str]) -> list[str]:
    seen: set[str] = set()
    candidates: list[str] = []
    for raw in [item_code, *support_codes]:
        normalized = _clean_text(raw)
        if not normalized:
            continue
        key = normalized.lower()
        if key in seen:
            continue
        seen.add(key)
        candidates.append(normalized)
    return candidates


def _resolve_image_content_type(file_path: Path) -> str:
    mimetypes.add_type("image/heic", ".heic")
    mimetypes.add_type("image/heif", ".heif")
    mimetypes.add_type("image/avif", ".avif")
    mimetypes.add_type("image/svg+xml", ".svg")
    mimetypes.add_type("image/svg+xml", ".svgz")
    mimetypes.add_type("image/x-icon", ".ico")
    content_type, _ = mimetypes.guess_type(file_path.name)
    if content_type:
        return content_type
    if file_path.suffix:
        return "application/octet-stream"
    return "application/octet-stream"


def _resolve_item_image(item_code: str, support_codes: list[str]) -> tuple[dict[str, Any], Path | None]:
    photo_dir = Path(settings.photo_dir)
    if not photo_dir.exists() or not photo_dir.is_dir():
        return (
            {
                "available": False,
                "fileName": None,
                "fileExtension": None,
                "contentType": None,
                "url": None,
            },
            None,
        )

    candidates = _image_candidates(item_code, support_codes)
    candidate_keys = {candidate.lower() for candidate in candidates}
    matched_files: list[tuple[int, Path, str]] = []

    for file_path in photo_dir.iterdir():
        if not file_path.is_file():
            continue
        if file_path.stem.lower() not in candidate_keys:
            continue
        content_type = _resolve_image_content_type(file_path)
        suffix = file_path.suffix.lower()
        priority = 0
        if content_type.startswith("image/"):
            priority += 10
        if suffix in PREFERRED_IMAGE_EXTENSIONS:
            priority += 5
        matched_files.append((priority, file_path, content_type))

    if matched_files:
        matched_files.sort(key=lambda item: (-item[0], item[1].suffix.lower(), item[1].name.lower()))
        _priority, file_path, content_type = matched_files[0]
        item_lookup = quote(item_code, safe="")
        return (
            {
                "available": True,
                "fileName": file_path.name,
                "fileExtension": file_path.suffix,
                "contentType": content_type,
                "url": f"/api/items/detail/{item_lookup}/image",
            },
            file_path,
        )

    return (
        {
            "available": False,
            "fileName": None,
            "fileExtension": None,
            "contentType": None,
            "url": None,
        },
        None,
    )


def _load_branch_stocks(cursor: Any, item_master_code: int) -> list[dict[str, Any]]:
    cursor.execute(
        """
        SELECT
            b.Code AS branchCode,
            b.Name AS branchName,
            COALESCE(SUM(CAST(ISNULL(t.D1, 0) AS DECIMAL(18, 2))), 0) AS itemQuantity,
            COALESCE(SUM(CAST(ISNULL(t.D3, 0) AS DECIMAL(18, 2))), 0) AS itemQuantityValue
        FROM dbo.Master1 b
        LEFT JOIN dbo.Tran4 t
            ON t.MasterCode2 = b.Code
           AND t.RecType = 0
           AND t.MasterCode1 = %(item_master_code)s
        LEFT JOIN dbo.Tran1 v
            ON v.VchCode = t.VchCode
        WHERE b.MasterType = 11
          AND (
            t.VchCode IS NULL
            OR CAST(v.[Date] AS DATE) <= CAST(GETDATE() AS DATE)
          )
        GROUP BY b.Code, b.Name
        ORDER BY b.Code ASC;
        """,
        {"item_master_code": item_master_code},
    )
    return [_serialize_row(row) for row in rows_to_dicts(cursor)]


def _load_price_category_names(cursor: Any) -> dict[int, str]:
    cursor.execute(
        """
        SELECT
            I3 AS categoryNo,
            MAX(CASE WHEN Name LIKE '%Price%' THEN Name END) AS namedCategory
        FROM dbo.Master1
        WHERE MasterType = 2
          AND I3 BETWEEN 1 AND 26
        GROUP BY I3;
        """
    )
    category_names: dict[int, str] = {}
    for row in rows_to_dicts(cursor):
        category_no = int(row["categoryNo"])
        _, category_code = _slot_to_category(100 + category_no)
        category_names[category_no] = _clean_text(row.get("namedCategory")) or f"{category_code} Price"
    return category_names


def list_price_categories() -> list[dict[str, Any]]:
    with db_connection(autocommit=True) as connection:
        cursor = connection.cursor()
        category_names = _load_price_category_names(cursor)
        cursor.execute(
            """
            WITH ItemCategoryAgg AS (
                SELECT
                    I1 - 100 AS categoryNo,
                    COUNT(DISTINCT MasterCode) AS itemCount,
                    COUNT(DISTINCT CASE WHEN ISNULL(D2, 0) > 0 THEN MasterCode END) AS discountedItemCount,
                    MIN(CASE WHEN ISNULL(D1, 0) > 0
                        THEN CAST(D1 - ((D1 * ISNULL(D2, 0)) / 100.0) AS DECIMAL(18, 2)) END) AS minFinalPrice,
                    MAX(CASE WHEN ISNULL(D1, 0) > 0
                        THEN CAST(D1 - ((D1 * ISNULL(D2, 0)) / 100.0) AS DECIMAL(18, 2)) END) AS maxFinalPrice
                FROM dbo.MasterSupport
                WHERE MasterType = 6
                  AND I1 BETWEEN 101 AND 126
                GROUP BY I1
            ),
            PartyCategoryAgg AS (
                SELECT
                    I3 AS categoryNo,
                    COUNT(*) AS accountCount
                FROM dbo.Master1
                WHERE MasterType = 2
                  AND I3 BETWEEN 1 AND 26
                GROUP BY I3
            ),
            CategoryList AS (
                SELECT categoryNo FROM ItemCategoryAgg
                UNION
                SELECT categoryNo FROM PartyCategoryAgg
            )
            SELECT
                cl.categoryNo,
                ISNULL(ica.itemCount, 0) AS itemCount,
                ISNULL(pca.accountCount, 0) AS accountCount,
                ISNULL(ica.discountedItemCount, 0) AS discountedItemCount,
                ica.minFinalPrice,
                ica.maxFinalPrice
            FROM CategoryList cl
            LEFT JOIN ItemCategoryAgg ica
                ON ica.categoryNo = cl.categoryNo
            LEFT JOIN PartyCategoryAgg pca
                ON pca.categoryNo = cl.categoryNo
            WHERE cl.categoryNo BETWEEN 1 AND 26
            ORDER BY cl.categoryNo ASC;
            """
        )
        rows = rows_to_dicts(cursor)

    categories: list[dict[str, Any]] = []
    for row in rows:
        category_no = int(row["categoryNo"])
        slot_id = 100 + category_no
        _, category_code = _slot_to_category(slot_id)
        categories.append(
            {
                "categoryNo": category_no,
                "categoryCode": category_code,
                "slotId": slot_id,
                "categoryName": category_names.get(category_no, f"{category_code} Price"),
                "itemCount": int(row.get("itemCount") or 0),
                "accountCount": int(row.get("accountCount") or 0),
                "discountedItemCount": int(row.get("discountedItemCount") or 0),
                "minFinalPrice": _serialize(row.get("minFinalPrice")),
                "maxFinalPrice": _serialize(row.get("maxFinalPrice")),
            }
        )
    return categories


def ensure_order_schema() -> None:
    with db_connection() as connection:
        cursor = connection.cursor()
        cursor.execute(ENSURE_ORDER_SCHEMA_SQL)
        connection.commit()


def list_items(*, search: str, item_code: str, item_name: str, qr_code: str, offset: int, page_size: int) -> dict[str, Any]:
    code_filter = _clean_text(qr_code) or _clean_text(item_code)
    search_filter = _clean_text(search)

    params = {
        "item_code_pattern": _like_pattern(code_filter),
        "item_name_pattern": _like_pattern(item_name),
        "search_filter": search_filter,
        "search_pattern": _like_pattern(search_filter),
        "offset": offset,
        "page_size": page_size,
    }

    count_sql = f"""
    {ITEM_BASE_CTE}
    SELECT COUNT(*) AS totalCount
    FROM ItemBase
    WHERE itemCode LIKE %(item_code_pattern)s
      AND itemName LIKE %(item_name_pattern)s
      AND (
        %(search_filter)s = ''
        OR itemCode LIKE %(search_pattern)s
        OR itemName LIKE %(search_pattern)s
      );
    """

    data_sql = f"""
    {ITEM_BASE_CTE}
    SELECT
        itemMasterCode,
        itemCode,
        itemCode AS qrCode,
        itemName,
        itemGroup,
        itemQuantity,
        itemQuantityValue,
        hsnCode,
        sellingRateHint,
        costRateHint,
        priceCount,
        minFinalPrice,
        maxFinalPrice
    FROM ItemBase
    WHERE itemCode LIKE %(item_code_pattern)s
      AND itemName LIKE %(item_name_pattern)s
      AND (
        %(search_filter)s = ''
        OR itemCode LIKE %(search_pattern)s
        OR itemName LIKE %(search_pattern)s
      )
    ORDER BY itemName ASC, itemMasterCode ASC
    OFFSET %(offset)s ROWS FETCH NEXT %(page_size)s ROWS ONLY;
    """

    with db_connection(autocommit=True) as connection:
        cursor = connection.cursor()
        cursor.execute(count_sql, params)
        total_count = int(cursor.fetchone()[0])
        cursor.execute(data_sql, params)
        items = [_serialize_row(row) for row in rows_to_dicts(cursor)]

        support_codes_by_item = _load_support_codes_for_items(
            cursor,
            [int(item.get("itemMasterCode") or 0) for item in items],
        )

    for item in items:
        support_codes = support_codes_by_item.get(
            int(item.get("itemMasterCode") or 0),
            [],
        )
        image, _image_path = _resolve_item_image(
            str(item.get("itemCode") or ""),
            support_codes,
        )
        item["image"] = image

    return {"items": items, "totalCount": total_count, "qrCodeAvailable": True}


def _load_support_codes_for_items(
    cursor: Any,
    item_master_codes: list[int],
) -> dict[int, list[str]]:
    codes = sorted({code for code in item_master_codes if code > 0})
    if not codes:
        return {}

    params = {f"code_{index}": code for index, code in enumerate(codes)}
    placeholders = ", ".join(f"%({key})s" for key in params)
    cursor.execute(
        f"""
        SELECT
            MasterCode,
            C1,
            SrNo
        FROM dbo.MasterSupport
        WHERE MasterType = 6
          AND MasterCode IN ({placeholders})
          AND NULLIF(C1, '') IS NOT NULL
        ORDER BY MasterCode ASC, SrNo ASC;
        """,
        params,
    )

    support_codes_by_item: dict[int, list[str]] = {}
    seen_by_item: dict[int, set[str]] = {}
    for row in rows_to_dicts(cursor):
        master_code = int(row.get("MasterCode") or 0)
        support_code = _clean_text(row.get("C1"))
        if master_code <= 0 or not support_code:
            continue

        seen = seen_by_item.setdefault(master_code, set())
        normalized = support_code.lower()
        if normalized in seen:
            continue

        seen.add(normalized)
        support_codes_by_item.setdefault(master_code, []).append(support_code)

    return support_codes_by_item


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
            CAST(COALESCE(NULLIF(m.Alias, ''), msa.supportItemCode, CAST(m.Code AS NVARCHAR(50))) AS NVARCHAR(100)) AS qrCode,
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
                    CAST(COALESCE(NULLIF(m.Alias, ''), msa.supportItemCode, CAST(m.Code AS NVARCHAR(50))) AS NVARCHAR(50)) = %(item_code)s
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


def _build_item_detail(cursor: Any, item_lookup: str) -> tuple[dict[str, Any] | None, Path | None]:
    reference = find_item_reference(
        item_master_code=None,
        item_code=item_lookup,
        item_name=None,
        cursor=cursor,
    )
    if not reference:
        return None, None

    cursor.execute(
        f"""
        {ITEM_BASE_CTE}
        SELECT TOP 1
            itemMasterCode,
            itemCode,
            itemCode AS qrCode,
            itemName,
            itemGroup,
            itemQuantity,
            itemQuantityValue,
            hsnCode,
            sellingRateHint,
            costRateHint,
            priceCount,
            minFinalPrice,
            maxFinalPrice
        FROM ItemBase
        WHERE itemMasterCode = %(item_master_code)s;
        """,
        {"item_master_code": reference["itemMasterCode"]},
    )
    header_rows = rows_to_dicts(cursor)
    if not header_rows:
        return None, None

    header = _serialize_row(header_rows[0])
    branch_stocks = _load_branch_stocks(cursor, int(reference["itemMasterCode"]))

    cursor.execute(
        """
        SELECT
            MasterCode,
            C1,
            I1,
            I2,
            D1,
            D2,
            D3,
            D5,
            [Date],
            SrNo
        FROM dbo.MasterSupport
        WHERE MasterType = 6
          AND MasterCode = %(item_master_code)s
        ORDER BY [Date] DESC, SrNo DESC, I1 ASC;
        """,
        {"item_master_code": reference["itemMasterCode"]},
    )
    support_rows = [_serialize_row(row) for row in rows_to_dicts(cursor)]

    support_item_codes: list[str] = []
    support_code_seen: set[str] = set()
    latest_price_rows: dict[int, dict[str, Any]] = {}
    latest_reference_row: dict[str, Any] | None = None

    for row in support_rows:
        support_code = _clean_text(row.get("C1"))
        if support_code and support_code.lower() not in support_code_seen:
            support_code_seen.add(support_code.lower())
            support_item_codes.append(support_code)

        slot_id = int(row.get("I1") or 0)
        if PRICE_SLOT_MIN <= slot_id <= PRICE_SLOT_MAX:
            latest_price_rows.setdefault(slot_id, row)
        elif slot_id == REFERENCE_SLOT_ID and latest_reference_row is None:
            latest_reference_row = row

    category_names = _load_price_category_names(cursor)
    prices: list[dict[str, Any]] = []
    for slot_id in sorted(latest_price_rows):
        row = latest_price_rows[slot_id]
        base_price = float(row.get("D1") or 0)
        discount_percent = float(row.get("D2") or 0)
        if base_price <= 0 and discount_percent <= 0:
            continue
        category_no, category_code = _slot_to_category(slot_id)
        prices.append(
            {
                "slotId": slot_id,
                "categoryNo": category_no,
                "categoryCode": category_code,
                "categoryName": category_names.get(category_no, f"{category_code} Price"),
                "basePrice": base_price,
                "discountPercent": discount_percent,
                "finalPrice": _compute_final_price(base_price, discount_percent),
                "effectiveDate": row.get("Date"),
            }
        )

    image, image_path = _resolve_item_image(str(header.get("itemCode") or ""), support_item_codes)

    reference_pricing = None
    if latest_reference_row and (
        float(latest_reference_row.get("D3") or 0) > 0 or float(latest_reference_row.get("D5") or 0) > 0
    ):
        reference_pricing = {
            "slotId": REFERENCE_SLOT_ID,
            "effectiveDate": latest_reference_row.get("Date"),
            "valueD3": float(latest_reference_row.get("D3") or 0) or None,
            "valueD5": float(latest_reference_row.get("D5") or 0) or None,
        }

    detail = {
        **header,
        "qrCode": header.get("itemCode"),
        "supportItemCodes": support_item_codes,
        "image": image,
        "prices": prices,
        "branchStocks": branch_stocks,
        "referencePricing": reference_pricing,
    }
    return detail, image_path


def get_item_detail(item_lookup: str) -> dict[str, Any] | None:
    with db_connection(autocommit=True) as connection:
        cursor = connection.cursor()
        detail, _image_path = _build_item_detail(cursor, item_lookup)
        return detail


def get_item_image_path(item_lookup: str) -> tuple[dict[str, Any] | None, Path | None]:
    with db_connection(autocommit=True) as connection:
        cursor = connection.cursor()
        return _build_item_detail(cursor, item_lookup)


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
        item_rows = rows_to_dicts(cursor)
        order_items: list[dict[str, Any]] = []
        for row in item_rows:
            item_code = _clean_text(row.get("item_code"))
            item_name_value = _clean_text(row.get("item_name"))
            item_detail = None
            lookup = item_code or item_name_value
            if lookup:
                try:
                    item_detail, _image_path = _build_item_detail(cursor, lookup)
                except Exception:
                    item_detail = None

            order_items.append(
                {
                    "id": _serialize(row["id"]),
                    "lineNo": _serialize(row["line_no"]),
                    "itemMasterCode": _serialize(row["item_master_code"]),
                    "itemCode": _serialize(row["item_code"]),
                    "qrCode": _serialize(row["qr_code"]),
                    "itemName": _serialize(row["item_name"]),
                    "quantity": _serialize(row["quantity"]),
                    "createdAt": _serialize(row["created_at"]),
                    "itemDetails": item_detail,
                }
            )

        order["items"] = order_items
        return order
