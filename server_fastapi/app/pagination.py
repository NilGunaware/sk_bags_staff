from __future__ import annotations

from dataclasses import dataclass

from .config import settings


@dataclass(frozen=True)
class PaginationParams:
    page: int
    page_size: int
    offset: int


def normalize_pagination(page: int = 1, page_size: int | None = None) -> PaginationParams:
    safe_page = max(page or 1, 1)
    requested_page_size = page_size or settings.default_page_size
    safe_page_size = min(max(requested_page_size, 1), settings.max_page_size)
    return PaginationParams(
        page=safe_page,
        page_size=safe_page_size,
        offset=(safe_page - 1) * safe_page_size,
    )


def build_pagination_meta(total_count: int, page: int, page_size: int) -> dict[str, int]:
    total_pages = (total_count + page_size - 1) // page_size if total_count else 0
    return {
        "page": page,
        "pageSize": page_size,
        "totalCount": total_count,
        "totalPages": total_pages,
    }
