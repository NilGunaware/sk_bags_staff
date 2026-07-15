from __future__ import annotations

from contextlib import asynccontextmanager
from datetime import date
import json
import logging
from fastapi import FastAPI, HTTPException, Query, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from .config import settings
from .pagination import build_pagination_meta, normalize_pagination
from .schemas import (
    ErrorResponse,
    HealthResponse,
    ItemDetailResponse,
    ItemFilters,
    ItemListResponse,
    OrderCreateRequest,
    OrderCreateResponse,
    OrderDetailResponse,
    OrderFilters,
    OrderItemFilters,
    OrderListResponse,
    PriceCategoryListResponse,
    RootResponse,
)
from .runtime import static_dir
from .db import assert_database_reachable_for_startup
from .service import (
    create_order,
    ensure_order_schema,
    get_item_detail,
    get_item_image_path,
    get_order_detail,
    list_items,
    list_orders,
    list_price_categories,
)
from .version import APP_VERSION


logger = logging.getLogger("uvicorn.error")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    logger.info("Running startup database check for %s at %s:%s", settings.db_name, settings.db_host, settings.db_port)
    try:
        assert_database_reachable_for_startup()
        ensure_order_schema()
    except Exception as error:
        logger.error("Startup failed while preparing the database: %s", error)
        raise

    logger.info("Startup database check passed.")
    yield


app = FastAPI(
    title="SK Bags FastAPI Service",
    version=APP_VERSION,
    description=(
        "FastAPI service for the recent BUSY database `BusyComp0019_db12026`. "
        "Use `/docs` for Swagger UI and `/redoc` for ReDoc."
    ),
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

STATIC_DIR = static_dir()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


def _should_log_api_body(path: str) -> bool:
    return path == "/health" or path.startswith("/api/")


def _is_json_content_type(content_type: str) -> bool:
    return "application/json" in content_type.lower()


def _format_json_log(raw_value: bytes | str | object | None) -> str:
    if raw_value is None:
        return "{}"

    try:
        if isinstance(raw_value, bytes):
            if not raw_value:
                return "{}"
            raw_value = raw_value.decode("utf-8", errors="replace")

        if isinstance(raw_value, str):
            stripped = raw_value.strip()
            if not stripped:
                return "{}"
            raw_value = json.loads(stripped)

        return json.dumps(raw_value, indent=2, ensure_ascii=False, default=str)
    except Exception:
        return str(raw_value)


@app.middleware("http")
async def log_api_request_response(request: Request, call_next):
    if not _should_log_api_body(request.url.path):
        return await call_next(request)

    request_body = await request.body()

    async def receive_logged_body():
        return {"type": "http.request", "body": request_body, "more_body": False}

    request._receive = receive_logged_body
    logger.info(
        "========== API REQUEST ==========\n%s %s\nBody: %s",
        request.method,
        request.url,
        _format_json_log(request_body),
    )

    try:
        response = await call_next(request)
    except Exception as error:
        logger.info(
            "========== API RESPONSE ==========\n%s %s [ERROR]\nBody: %s",
            request.method,
            request.url,
            _format_json_log({"error": str(error)}),
        )
        raise

    content_type = response.headers.get("content-type", "")
    if not _is_json_content_type(content_type):
        logger.info(
            "========== API RESPONSE ==========\n%s %s [%s]\nBody: %s",
            request.method,
            request.url,
            response.status_code,
            "<non-json response omitted>",
        )
        return response

    response_body = b"".join([chunk async for chunk in response.body_iterator])
    logger.info(
        "========== API RESPONSE ==========\n%s %s [%s]\nBody: %s",
        request.method,
        request.url,
        response.status_code,
        _format_json_log(response_body),
    )
    return Response(
        content=response_body,
        status_code=response.status_code,
        headers=dict(response.headers),
        media_type=response.media_type,
        background=response.background,
    )


def _page(filename: str) -> FileResponse:
    return FileResponse(STATIC_DIR / filename)


def _parse_optional_date(value: str | None, field_name: str) -> date | None:
    if value is None:
        return None

    stripped = value.strip()
    if stripped == "":
        return None

    try:
        return date.fromisoformat(stripped)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=f"{field_name} must be in YYYY-MM-DD format.") from error


@app.get("/", include_in_schema=False)
def root() -> FileResponse:
    return _page("index.html")


@app.get("/orders", include_in_schema=False)
def orders_page() -> FileResponse:
    return _page("orders.html")


@app.get("/orders/new", include_in_schema=False)
def order_create_page() -> FileResponse:
    return _page("order-create.html")


@app.get("/orders/{order_id}", include_in_schema=False)
def order_detail_page(order_id: int) -> FileResponse:
    return _page("order-detail.html")


@app.get("/items", include_in_schema=False)
def items_page() -> FileResponse:
    return _page("items.html")


@app.get("/api/meta", response_model=RootResponse, tags=["Meta"])
def api_meta() -> RootResponse:
    return RootResponse(
        service="SK Bags FastAPI Service",
        database=settings.db_name,
        docsUrl="/docs",
        redocUrl="/redoc",
        openApiUrl="/openapi.json",
        endpoints=[
            "GET /health",
            "GET /api/items",
            "GET /api/items/detail/{item_lookup}",
            "GET /api/items/detail/{item_lookup}/image",
            "GET /api/price-categories",
            "POST /api/orders",
            "GET /api/orders",
            "GET /api/orders/{order_id}",
        ],
    )


@app.get("/health", response_model=HealthResponse, tags=["Meta"])
def health() -> HealthResponse:
    return HealthResponse(status="ok", database=settings.db_name, version=APP_VERSION)


@app.get(
    "/api/items",
    response_model=ItemListResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
    tags=["Items"],
    summary="List items",
)
def items(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, alias="pageSize", ge=1),
    search: str = Query("", alias="search"),
    item_code: str = Query("", alias="itemCode"),
    item_name: str = Query("", alias="itemName"),
    qr_code: str = Query("", alias="qrCode"),
) -> ItemListResponse:
    pagination = normalize_pagination(page, page_size)
    result = list_items(
        search=search,
        item_code=item_code,
        item_name=item_name,
        qr_code=qr_code,
        offset=pagination.offset,
        page_size=pagination.page_size,
    )
    return ItemListResponse(
        data=result["items"],
        pagination=build_pagination_meta(result["totalCount"], pagination.page, pagination.page_size),
        filters=ItemFilters(
            search=search.strip(),
            itemCode=item_code.strip(),
            itemName=item_name.strip(),
            qrCode=qr_code.strip(),
            qrCodeAvailable=result["qrCodeAvailable"],
        ),
    )


@app.get(
    "/api/items/detail/{item_lookup}/image",
    responses={404: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
    tags=["Items"],
    summary="Get item image",
)
def item_image(item_lookup: str) -> FileResponse:
    detail, image_path = get_item_image_path(item_lookup.strip())
    if not detail:
        raise HTTPException(status_code=404, detail="Item not found.")
    if not image_path or not detail["image"]["available"]:
        raise HTTPException(status_code=404, detail="Image not found for this item.")
    return FileResponse(
        image_path,
        media_type=detail["image"]["contentType"],
        filename=detail["image"]["fileName"],
    )


@app.get(
    "/api/items/detail/{item_lookup}",
    response_model=ItemDetailResponse,
    responses={404: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
    tags=["Items"],
    summary="Get complete item details",
)
def item_detail(item_lookup: str) -> ItemDetailResponse:
    detail = get_item_detail(item_lookup.strip())
    if not detail:
        raise HTTPException(status_code=404, detail="Item not found.")
    return ItemDetailResponse(data=detail)


@app.get(
    "/api/price-categories",
    response_model=PriceCategoryListResponse,
    responses={500: {"model": ErrorResponse}},
    tags=["Items"],
    summary="List BUSY price categories",
)
def price_categories() -> PriceCategoryListResponse:
    return PriceCategoryListResponse(data=list_price_categories())


@app.post(
    "/api/orders",
    response_model=OrderCreateResponse,
    status_code=201,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
    tags=["Orders"],
    summary="Create an order",
)
def orders_create(payload: OrderCreateRequest) -> OrderCreateResponse:
    try:
        created = create_order(payload.model_dump())
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except Exception as error:
        raise HTTPException(status_code=500, detail=str(error)) from error

    return OrderCreateResponse(message="Order created successfully.", data=created)


@app.get(
    "/api/orders",
    response_model=OrderListResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
    tags=["Orders"],
    summary="List orders",
)
def orders_list(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, alias="pageSize", ge=1),
    order_no: str = Query("", alias="orderNo"),
    series_code: str = Query("", alias="seriesCode"),
    party_name: str = Query("", alias="partyName"),
    item_code: str = Query("", alias="itemCode"),
    item_name: str = Query("", alias="itemName"),
    from_date_raw: str | None = Query(None, alias="fromDate"),
    to_date_raw: str | None = Query(None, alias="toDate"),
) -> OrderListResponse:
    from_date = _parse_optional_date(from_date_raw, "fromDate")
    to_date = _parse_optional_date(to_date_raw, "toDate")

    if from_date and to_date and from_date > to_date:
        raise HTTPException(status_code=400, detail="fromDate cannot be after toDate.")

    pagination = normalize_pagination(page, page_size)
    result = list_orders(
        order_no=order_no,
        series_code=series_code,
        party_name=party_name,
        item_code=item_code,
        item_name=item_name,
        from_date=from_date,
        to_date=to_date,
        offset=pagination.offset,
        page_size=pagination.page_size,
    )
    return OrderListResponse(
        data=result["orders"],
        pagination=build_pagination_meta(result["totalCount"], pagination.page, pagination.page_size),
        filters=OrderFilters(
            orderNo=order_no.strip(),
            seriesCode=series_code.strip(),
            partyName=party_name.strip(),
            itemCode=item_code.strip(),
            itemName=item_name.strip(),
            fromDate=from_date,
            toDate=to_date,
        ),
    )


@app.get(
    "/api/orders/{order_id}",
    response_model=OrderDetailResponse,
    responses={400: {"model": ErrorResponse}, 404: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
    tags=["Orders"],
    summary="Get order details",
)
def orders_detail(
    order_id: int,
    item_page: int = Query(1, alias="itemPage", ge=1),
    item_page_size: int = Query(
        settings.max_page_size,
        alias="itemPageSize",
        ge=1,
    ),
    item_code: str = Query("", alias="itemCode"),
    item_name: str = Query("", alias="itemName"),
) -> OrderDetailResponse:
    item_pagination = normalize_pagination(item_page, item_page_size)
    detail = get_order_detail(
        order_id,
        item_code=item_code,
        item_name=item_name,
        offset=item_pagination.offset,
        page_size=item_pagination.page_size,
    )
    if not detail:
        raise HTTPException(status_code=404, detail="Order not found.")

    return OrderDetailResponse(
        data=detail,
        itemPagination=build_pagination_meta(
            detail["itemTotalCount"],
            item_pagination.page,
            item_pagination.page_size,
        ),
        filters=OrderItemFilters(itemCode=item_code.strip(), itemName=item_name.strip()),
    )
