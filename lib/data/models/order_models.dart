class OrderListPage {
  const OrderListPage({
    required this.orders,
    required this.hasMore,
    required this.totalCount,
  });

  final List<OrderSummaryModel> orders;
  final bool hasMore;
  final int totalCount;
}

class OrderSummaryModel {
  const OrderSummaryModel({
    required this.id,
    required this.uuid,
    required this.entryNo,
    required this.entryDate,
    required this.partyName,
    required this.partyMobile,
    required this.totalQty,
    required this.raw,
  });

  final String id;
  final String uuid;
  final String entryNo;
  final String entryDate;
  final String partyName;
  final String partyMobile;
  final int totalQty;
  final Map<String, dynamic> raw;

  factory OrderSummaryModel.fromJson(Map<String, dynamic> json) {
    return OrderSummaryModel(
      id: (json['id'] ?? '').toString(),
      uuid: (json['uuid'] ?? '').toString(),
      entryNo: (json['entry_no'] ?? json['entryNo'] ?? '').toString(),
      entryDate: (json['entry_date'] ?? json['date'] ?? '').toString(),
      partyName: (json['party_name'] ?? json['partyName'] ?? '').toString(),
      partyMobile: (json['party_mobile'] ?? json['partyMobile'] ?? '')
          .toString(),
      totalQty: _parseInt(json['total_qty'] ?? json['totalQty'] ?? json['qty']),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

class OrderDetailModel {
  const OrderDetailModel({
    required this.summary,
    required this.items,
    required this.raw,
  });

  final OrderSummaryModel summary;
  final List<OrderItemModel> items;
  final Map<String, dynamic> raw;
}

class OrderItemModel {
  const OrderItemModel({
    required this.id,
    required this.itemCode,
    required this.itemName,
    required this.quantity,
  });

  final String id;
  final String itemCode;
  final String itemName;
  final int quantity;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: (json['id'] ?? '').toString(),
      itemCode: (json['item_code'] ?? json['itemCode'] ?? json['code'] ?? '')
          .toString(),
      itemName: (json['item_name'] ?? json['itemName'] ?? json['name'] ?? '')
          .toString(),
      quantity: _parseInt(
        json['qty'] ??
            json['quantity'] ??
            json['item_qty'] ??
            json['itemQuantity'] ??
            json['item_quantity'] ??
            json['order_qty'] ??
            json['orderQuantity'] ??
            json['total_qty'] ??
            json['totalQty'],
      ),
    );
  }
}

class MergedItemPage {
  const MergedItemPage({
    required this.items,
    required this.hasMore,
    required this.warnings,
  });

  final List<MergedItemModel> items;
  final bool hasMore;
  final List<String> warnings;
}

class MergedItemModel {
  const MergedItemModel({
    required this.itemCode,
    required this.itemName,
    required this.totalQuantity,
    required this.serverQuantities,
    this.qrCode,
  });

  final String itemCode;
  final String itemName;
  final int totalQuantity;
  final Map<String, int> serverQuantities;
  final String? qrCode;

  String get key => '${itemCode.trim()}|${itemName.trim()}';

  MergedItemModel merge(MergedItemModel other) {
    final mergedQuantities = <String, int>{...serverQuantities};

    other.serverQuantities.forEach((server, quantity) {
      mergedQuantities[server] = (mergedQuantities[server] ?? 0) + quantity;
    });

    return MergedItemModel(
      itemCode: itemCode,
      itemName: itemName,
      totalQuantity: totalQuantity + other.totalQuantity,
      serverQuantities: mergedQuantities,
      qrCode: (qrCode?.trim().isNotEmpty ?? false) ? qrCode : other.qrCode,
    );
  }

  factory MergedItemModel.fromServerJson(
    Map<String, dynamic> json, {
    required String serverName,
  }) {
    final quantity = _parseInt(
      json['itemQuantity'] ?? json['quantity'] ?? json['qty'],
    );

    return MergedItemModel(
      itemCode: (json['itemCode'] ?? json['item_code'] ?? '').toString(),
      itemName: (json['itemName'] ?? json['item_name'] ?? '').toString(),
      totalQuantity: quantity,
      serverQuantities: <String, int>{serverName: quantity},
      qrCode: _parseNullableString(json['qrCode'] ?? json['qr_code']),
    );
  }
}

class PriceCategoryModel {
  const PriceCategoryModel({
    required this.categoryNo,
    required this.categoryCode,
    required this.slotId,
    required this.categoryName,
    required this.itemCount,
    required this.accountCount,
    required this.discountedItemCount,
    required this.minFinalPrice,
    required this.maxFinalPrice,
  });

  final int categoryNo;
  final String categoryCode;
  final int slotId;
  final String categoryName;
  final int itemCount;
  final int accountCount;
  final int discountedItemCount;
  final double minFinalPrice;
  final double maxFinalPrice;

  factory PriceCategoryModel.fromJson(Map<String, dynamic> json) {
    return PriceCategoryModel(
      categoryNo: _parseInt(json['categoryNo'] ?? json['category_no']),
      categoryCode: (json['categoryCode'] ?? json['category_code'] ?? '')
          .toString(),
      slotId: _parseInt(json['slotId'] ?? json['slot_id']),
      categoryName: (json['categoryName'] ?? json['category_name'] ?? '')
          .toString(),
      itemCount: _parseInt(json['itemCount'] ?? json['item_count']),
      accountCount: _parseInt(json['accountCount'] ?? json['account_count']),
      discountedItemCount: _parseInt(
        json['discountedItemCount'] ?? json['discounted_item_count'],
      ),
      minFinalPrice: _parseDouble(
        json['minFinalPrice'] ?? json['min_final_price'],
      ),
      maxFinalPrice: _parseDouble(
        json['maxFinalPrice'] ?? json['max_final_price'],
      ),
    );
  }
}

class ItemImageModel {
  const ItemImageModel({
    required this.available,
    this.url,
    this.fileName,
    this.fileExtension,
    this.contentType,
  });

  final bool available;
  final String? url;
  final String? fileName;
  final String? fileExtension;
  final String? contentType;

  factory ItemImageModel.fromJson(
    Map<String, dynamic> json, {
    required String baseUrl,
  }) {
    final rawUrl = _parseNullableString(json['url']);
    String? resolvedUrl = rawUrl;
    if (rawUrl != null && rawUrl.startsWith('/')) {
      resolvedUrl = '$baseUrl$rawUrl';
    }
    return ItemImageModel(
      available: json['available'] == true,
      url: resolvedUrl,
      fileName: _parseNullableString(json['fileName'] ?? json['file_name']),
      fileExtension: _parseNullableString(
        json['fileExtension'] ?? json['file_extension'],
      ),
      contentType: _parseNullableString(
        json['contentType'] ?? json['content_type'],
      ),
    );
  }
}

class ItemPriceModel {
  const ItemPriceModel({
    required this.slotId,
    required this.categoryNo,
    required this.categoryCode,
    required this.categoryName,
    required this.basePrice,
    required this.discountPercent,
    required this.finalPrice,
    this.effectiveDate,
  });

  final int slotId;
  final int categoryNo;
  final String categoryCode;
  final String categoryName;
  final double basePrice;
  final double discountPercent;
  final double finalPrice;
  final String? effectiveDate;

  factory ItemPriceModel.fromJson(Map<String, dynamic> json) {
    return ItemPriceModel(
      slotId: _parseInt(json['slotId'] ?? json['slot_id']),
      categoryNo: _parseInt(json['categoryNo'] ?? json['category_no']),
      categoryCode: (json['categoryCode'] ?? json['category_code'] ?? '')
          .toString(),
      categoryName: (json['categoryName'] ?? json['category_name'] ?? '')
          .toString(),
      basePrice: _parseDouble(json['basePrice'] ?? json['base_price']),
      discountPercent: _parseDouble(
        json['discountPercent'] ?? json['discount_percent'],
      ),
      finalPrice: _parseDouble(json['finalPrice'] ?? json['final_price']),
      effectiveDate: _parseNullableString(
        json['effectiveDate'] ?? json['effective_date'],
      ),
    );
  }
}

class BranchStockModel {
  const BranchStockModel({
    required this.branchCode,
    required this.branchName,
    required this.quantity,
    required this.quantityValue,
  });

  final int branchCode;
  final String branchName;
  final double quantity;
  final double quantityValue;

  factory BranchStockModel.fromJson(Map<String, dynamic> json) {
    return BranchStockModel(
      branchCode: _parseInt(json['branchCode'] ?? json['branch_code']),
      branchName: (json['branchName'] ?? json['branch_name'] ?? '').toString(),
      quantity: _parseDouble(
        json['itemQuantity'] ?? json['quantity'] ?? json['qty'],
      ),
      quantityValue: _parseDouble(
        json['itemQuantityValue'] ??
            json['quantityValue'] ??
            json['item_quantity_value'],
      ),
    );
  }
}

class MergedItemDetailModel {
  const MergedItemDetailModel({
    required this.itemCode,
    required this.itemName,
    required this.itemGroup,
    required this.totalQuantity,
    required this.totalQuantityValue,
    required this.serverQuantities,
    required this.serverBranchStocks,
    required this.prices,
    required this.warnings,
    this.itemMasterCode,
    this.qrCode,
    this.hsnCode,
    this.image,
    this.imageUrls = const <String>[],
    this.supportItemCodes = const <String>[],
  });

  final int? itemMasterCode;
  final String itemCode;
  final String itemName;
  final String itemGroup;
  final String? qrCode;
  final String? hsnCode;
  final double totalQuantity;
  final double totalQuantityValue;
  final Map<String, double> serverQuantities;
  final Map<String, List<BranchStockModel>> serverBranchStocks;
  final ItemImageModel? image;
  final List<String> imageUrls;
  final List<ItemPriceModel> prices;
  final List<String> supportItemCodes;
  final List<String> warnings;

  ItemPriceModel priceFor(PriceCategoryModel? category) {
    if (category == null) {
      return const ItemPriceModel(
        slotId: 0,
        categoryNo: 0,
        categoryCode: '',
        categoryName: 'No Category',
        basePrice: 0,
        discountPercent: 0,
        finalPrice: 0,
      );
    }

    for (final price in prices) {
      if (price.categoryNo == category.categoryNo ||
          price.slotId == category.slotId ||
          price.categoryCode.toLowerCase() ==
              category.categoryCode.toLowerCase() ||
          price.categoryName.toLowerCase() ==
              category.categoryName.toLowerCase()) {
        return price;
      }
    }

    return ItemPriceModel(
      slotId: category.slotId,
      categoryNo: category.categoryNo,
      categoryCode: category.categoryCode,
      categoryName: category.categoryName,
      basePrice: 0,
      discountPercent: 0,
      finalPrice: 0,
    );
  }

  double quantityForServer(String serverName) =>
      serverQuantities[serverName] ?? 0;

  List<BranchStockModel> branchesForServer(String serverName) =>
      serverBranchStocks[serverName] ?? const <BranchStockModel>[];

  int get availableOrderQuantity => totalQuantity.floor();
}

class CartItemModel {
  const CartItemModel({
    required this.itemCode,
    required this.itemName,
    required this.itemGroup,
    required this.quantity,
    required this.availableQuantity,
    required this.serverQuantities,
    required this.prices,
    this.itemMasterCode,
    this.qrCode,
    this.hsnCode,
    this.imageUrl,
    this.imageUrls = const <String>[],
  });

  final int? itemMasterCode;
  final String itemCode;
  final String itemName;
  final String itemGroup;
  final String? qrCode;
  final String? hsnCode;
  final String? imageUrl;
  final List<String> imageUrls;
  final int quantity;
  final int availableQuantity;
  final Map<String, double> serverQuantities;
  final List<ItemPriceModel> prices;

  String get key =>
      itemCode.trim().isNotEmpty ? itemCode.trim() : itemName.trim();

  CartItemModel copyWith({
    int? itemMasterCode,
    String? itemCode,
    String? itemName,
    String? itemGroup,
    String? qrCode,
    String? hsnCode,
    String? imageUrl,
    List<String>? imageUrls,
    int? quantity,
    int? availableQuantity,
    Map<String, double>? serverQuantities,
    List<ItemPriceModel>? prices,
  }) {
    return CartItemModel(
      itemMasterCode: itemMasterCode ?? this.itemMasterCode,
      itemCode: itemCode ?? this.itemCode,
      itemName: itemName ?? this.itemName,
      itemGroup: itemGroup ?? this.itemGroup,
      qrCode: qrCode ?? this.qrCode,
      hsnCode: hsnCode ?? this.hsnCode,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      quantity: quantity ?? this.quantity,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      serverQuantities: serverQuantities ?? this.serverQuantities,
      prices: prices ?? this.prices,
    );
  }

  factory CartItemModel.fromDetail(
    MergedItemDetailModel detail, {
    required int quantity,
  }) {
    return CartItemModel(
      itemMasterCode: detail.itemMasterCode,
      itemCode: detail.itemCode,
      itemName: detail.itemName,
      itemGroup: detail.itemGroup,
      qrCode: detail.qrCode,
      hsnCode: detail.hsnCode,
      imageUrl: detail.image?.url,
      imageUrls: detail.imageUrls,
      quantity: quantity,
      availableQuantity: detail.availableOrderQuantity,
      serverQuantities: detail.serverQuantities,
      prices: detail.prices,
    );
  }

  ItemPriceModel priceFor(PriceCategoryModel? category) {
    return MergedItemDetailModel(
      itemMasterCode: itemMasterCode,
      itemCode: itemCode,
      itemName: itemName,
      itemGroup: itemGroup,
      qrCode: qrCode,
      hsnCode: hsnCode,
      imageUrls: imageUrls,
      totalQuantity: availableQuantity.toDouble(),
      totalQuantityValue: 0,
      serverQuantities: serverQuantities,
      serverBranchStocks: const <String, List<BranchStockModel>>{},
      prices: prices,
      warnings: const <String>[],
    ).priceFor(category);
  }
}

class DraftOrderItem {
  const DraftOrderItem({
    required this.itemCode,
    required this.itemName,
    required this.availableQuantity,
    required this.quantity,
  });

  final String itemCode;
  final String itemName;
  final int availableQuantity;
  final int quantity;

  String get key => '${itemCode.trim()}|${itemName.trim()}';

  DraftOrderItem copyWith({
    String? itemCode,
    String? itemName,
    int? availableQuantity,
    int? quantity,
  }) {
    return DraftOrderItem(
      itemCode: itemCode ?? this.itemCode,
      itemName: itemName ?? this.itemName,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      quantity: quantity ?? this.quantity,
    );
  }
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return 0;
  }
  return int.tryParse(text) ?? double.tryParse(text)?.toInt() ?? 0;
}

double _parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return 0;
  }
  return double.tryParse(text) ?? 0;
}

String? _parseNullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
