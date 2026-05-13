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
    this.itemDetails,
  });

  final String id;
  final String itemCode;
  final String itemName;
  final int quantity;
  final MergedItemDetailModel? itemDetails;

  OrderItemModel copyWith({
    String? id,
    String? itemCode,
    String? itemName,
    int? quantity,
    MergedItemDetailModel? itemDetails,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      itemCode: itemCode ?? this.itemCode,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      itemDetails: itemDetails ?? this.itemDetails,
    );
  }

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final itemDetailsJson = json['itemDetails'] ?? json['item_details'];
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
      itemDetails: itemDetailsJson is Map
          ? MergedItemDetailModel.fromJson(
              Map<String, dynamic>.from(itemDetailsJson),
            )
          : null,
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
    this.imageUrls = const <String>[],
    this.qrCode,
  });

  final String itemCode;
  final String itemName;
  final int totalQuantity;
  final Map<String, int> serverQuantities;
  final List<String> imageUrls;
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
      imageUrls: <String>{
        ...imageUrls,
        ...other.imageUrls,
      }.where((url) => url.trim().isNotEmpty).toList(),
      qrCode: (qrCode?.trim().isNotEmpty ?? false) ? qrCode : other.qrCode,
    );
  }

  factory MergedItemModel.fromServerJson(
    Map<String, dynamic> json, {
    required String serverName,
    required String baseUrl,
  }) {
    final quantity = _parseInt(
      json['itemQuantity'] ?? json['quantity'] ?? json['qty'],
    );
    final imageJson = json['image'];
    final image = imageJson is Map
        ? ItemImageModel.fromJson(
            Map<String, dynamic>.from(imageJson),
            baseUrl: baseUrl,
          )
        : null;

    return MergedItemModel(
      itemCode: (json['itemCode'] ?? json['item_code'] ?? '').toString(),
      itemName: (json['itemName'] ?? json['item_name'] ?? '').toString(),
      totalQuantity: quantity,
      serverQuantities: <String, int>{serverName: quantity},
      imageUrls: <String>[
        if ((image?.available ?? false) && (image?.url?.isNotEmpty ?? false))
          image!.url!,
      ],
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

  String get displayCode => _businessPriceCode(categoryCode, categoryName);

  String get displayName =>
      _businessPriceName(displayCode, fallback: categoryName);

  bool get isPrimaryBusinessPrice =>
      _primaryBusinessPriceCodes.contains(displayCode);

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

  String get displayCode => _businessPriceCode(categoryCode, categoryName);

  String get displayName =>
      _businessPriceName(displayCode, fallback: categoryName);

  bool get isPrimaryBusinessPrice =>
      _primaryBusinessPriceCodes.contains(displayCode);

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

  factory MergedItemDetailModel.fromJson(Map<String, dynamic> json) {
    final imageJson = json['image'];
    final pricesJson = json['prices'];
    final branchStocksJson = json['branchStocks'] ?? json['branch_stocks'];

    return MergedItemDetailModel(
      itemMasterCode: _parseInt(
        json['itemMasterCode'] ?? json['item_master_code'],
      ),
      itemCode: (json['itemCode'] ?? json['item_code'] ?? '').toString(),
      itemName: (json['itemName'] ?? json['item_name'] ?? '').toString(),
      itemGroup: (json['itemGroup'] ?? json['item_group'] ?? '').toString(),
      qrCode: _parseNullableString(json['qrCode'] ?? json['qr_code']),
      hsnCode: _parseNullableString(json['hsnCode'] ?? json['hsn_code']),
      totalQuantity: _parseDouble(
        json['itemQuantity'] ?? json['quantity'] ?? json['qty'],
      ),
      totalQuantityValue: _parseDouble(
        json['itemQuantityValue'] ?? json['item_quantity_value'],
      ),
      serverQuantities: const <String, double>{},
      serverBranchStocks: <String, List<BranchStockModel>>{
        if (branchStocksJson is List)
          'All Branches': branchStocksJson
              .whereType<Map>()
              .map(
                (item) =>
                    BranchStockModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(),
      },
      image: imageJson is Map
          ? ItemImageModel.fromJson(
              Map<String, dynamic>.from(imageJson),
              baseUrl: '',
            )
          : null,
      imageUrls: imageJson is Map
          ? <String>[
              if (_parseNullableString(imageJson['url']) != null)
                _parseNullableString(imageJson['url'])!,
            ]
          : const <String>[],
      prices: pricesJson is List
          ? pricesJson
                .whereType<Map>()
                .map(
                  (item) =>
                      ItemPriceModel.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const <ItemPriceModel>[],
      supportItemCodes: json['supportItemCodes'] is List
          ? (json['supportItemCodes'] as List)
                .map((value) => value.toString())
                .where((value) => value.trim().isNotEmpty)
                .toList()
          : const <String>[],
      warnings: const <String>[],
    );
  }

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
    this.id = '',
    required this.itemCode,
    required this.itemName,
    required this.availableQuantity,
    required this.quantity,
  });

  final String id;
  final String itemCode;
  final String itemName;
  final int availableQuantity;
  final int quantity;

  String get key => '${itemCode.trim()}|${itemName.trim()}';

  DraftOrderItem copyWith({
    String? id,
    String? itemCode,
    String? itemName,
    int? availableQuantity,
    int? quantity,
  }) {
    return DraftOrderItem(
      id: id ?? this.id,
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

const Set<String> _primaryBusinessPriceCodes = {'A', 'W', 'C', 'H'};

String _businessPriceCode(String categoryCode, String categoryName) {
  final name = categoryName.trim().toUpperCase();
  if (name == 'W' || name.startsWith('W ')) {
    return 'W';
  }
  return categoryCode.trim().toUpperCase();
}

String _businessPriceName(String code, {required String fallback}) {
  switch (code.trim().toUpperCase()) {
    case 'A':
      return 'Retail';
    case 'W':
      return 'Whoslesale';
    case 'C':
      return 'Corperate Gst Inclusive';
    case 'H':
      return 'Franchise';
  }
  return fallback.trim().isEmpty ? code : fallback;
}
