from __future__ import annotations

from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, Field, model_validator


class RootResponse(BaseModel):
    service: str
    database: str
    docsUrl: str
    redocUrl: str
    openApiUrl: str
    endpoints: list[str]


class HealthResponse(BaseModel):
    status: str
    database: str


class PaginationMeta(BaseModel):
    page: int
    pageSize: int
    totalCount: int
    totalPages: int


class ItemFilters(BaseModel):
    itemCode: str
    itemName: str
    qrCode: str
    qrCodeAvailable: bool


class OrderFilters(BaseModel):
    orderNo: str
    seriesCode: str
    partyName: str
    itemCode: str
    itemName: str
    fromDate: date | None = None
    toDate: date | None = None


class OrderItemFilters(BaseModel):
    itemCode: str
    itemName: str


class ItemSummary(BaseModel):
    itemMasterCode: int
    itemCode: str | None = None
    qrCode: str | None = None
    itemName: str
    itemGroup: str
    itemQuantity: float
    itemQuantityValue: float
    hsnCode: str | None = None
    sellingRateHint: float | None = None
    costRateHint: float | None = None
    priceCount: int = 0
    minFinalPrice: float | None = None
    maxFinalPrice: float | None = None


class ItemListResponse(BaseModel):
    data: list[ItemSummary]
    pagination: PaginationMeta
    filters: ItemFilters


class ItemImageInfo(BaseModel):
    available: bool
    fileName: str | None = None
    fileExtension: str | None = None
    contentType: str | None = None
    url: str | None = None


class ItemPriceRow(BaseModel):
    slotId: int
    categoryNo: int
    categoryCode: str
    categoryName: str
    basePrice: float
    discountPercent: float
    finalPrice: float
    effectiveDate: date | None = None


class ItemReferencePricing(BaseModel):
    slotId: int
    effectiveDate: date | None = None
    valueD3: float | None = None
    valueD5: float | None = None


class ItemDetail(BaseModel):
    itemMasterCode: int
    itemCode: str | None = None
    qrCode: str | None = None
    itemName: str
    itemGroup: str
    itemQuantity: float
    itemQuantityValue: float
    hsnCode: str | None = None
    sellingRateHint: float | None = None
    costRateHint: float | None = None
    priceCount: int = 0
    minFinalPrice: float | None = None
    maxFinalPrice: float | None = None
    supportItemCodes: list[str] = Field(default_factory=list)
    image: ItemImageInfo
    prices: list[ItemPriceRow] = Field(default_factory=list)
    referencePricing: ItemReferencePricing | None = None


class ItemDetailResponse(BaseModel):
    data: ItemDetail


class PriceCategorySummary(BaseModel):
    categoryNo: int
    categoryCode: str
    slotId: int
    categoryName: str
    itemCount: int = 0
    accountCount: int = 0
    discountedItemCount: int = 0
    minFinalPrice: float | None = None
    maxFinalPrice: float | None = None


class PriceCategoryListResponse(BaseModel):
    data: list[PriceCategorySummary]


class OrderItemInput(BaseModel):
    itemMasterCode: int | None = Field(default=None, examples=[12047])
    itemCode: str | None = Field(default=None, examples=["44593"])
    itemName: str | None = Field(default=None, examples=["08088 Baby Bag Pulse"])
    quantity: float = Field(..., gt=0, examples=[5])

    @model_validator(mode="after")
    def validate_identifier(self) -> "OrderItemInput":
        if self.itemMasterCode or self.itemCode or self.itemName:
            return self
        raise ValueError("Each order item needs itemMasterCode, itemCode, or itemName.")


class OrderCreateRequest(BaseModel):
    orderDate: date | None = Field(default=None, examples=["2026-04-14"])
    seriesCode: str | None = Field(default=None, examples=["12/Abo"])
    partyName: str = Field(..., min_length=1, examples=["Bag Bazaar Vorabazar"])
    items: list[OrderItemInput] = Field(..., min_length=1)

    model_config = {
        "json_schema_extra": {
            "example": {
                "orderDate": "2026-04-14",
                "seriesCode": "12/Abo",
                "partyName": "Bag Bazaar Vorabazar",
                "items": [
                    {"itemCode": "44593", "quantity": 1},
                    {"itemCode": "46598", "quantity": 5},
                ],
            }
        }
    }


class OrderItemSummary(BaseModel):
    id: int
    lineNo: int
    itemMasterCode: int | None = None
    itemCode: str | None = None
    qrCode: str | None = None
    itemName: str
    quantity: float
    createdAt: datetime


class OrderSummary(BaseModel):
    id: int
    orderNo: str
    orderDate: date
    seriesCode: str | None = None
    partyName: str
    partyMasterCode: int | None = None
    totalItems: int
    totalQuantity: float
    createdAt: datetime
    updatedAt: datetime


class OrderDetail(OrderSummary):
    itemTotalCount: int
    items: list[OrderItemSummary]


class OrderListResponse(BaseModel):
    data: list[OrderSummary]
    pagination: PaginationMeta
    filters: OrderFilters


class OrderDetailResponse(BaseModel):
    data: OrderDetail
    itemPagination: PaginationMeta
    filters: OrderItemFilters


class OrderCreateResponse(BaseModel):
    message: str
    data: OrderDetail


class ErrorResponse(BaseModel):
    message: str
    detail: Any | None = None
