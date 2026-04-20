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
      partyMobile: (json['party_mobile'] ?? json['partyMobile'] ?? '').toString(),
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
      quantity: _parseInt(json['qty'] ?? json['quantity']),
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
  });

  final String itemCode;
  final String itemName;
  final int totalQuantity;
  final Map<String, int> serverQuantities;

  String get key => '${itemCode.trim()}|${itemName.trim()}';

  MergedItemModel merge(MergedItemModel other) {
    final mergedQuantities = <String, int>{
      ...serverQuantities,
    };

    other.serverQuantities.forEach((server, quantity) {
      mergedQuantities[server] = (mergedQuantities[server] ?? 0) + quantity;
    });

    return MergedItemModel(
      itemCode: itemCode,
      itemName: itemName,
      totalQuantity: totalQuantity + other.totalQuantity,
      serverQuantities: mergedQuantities,
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
      serverQuantities: <String, int>{
        serverName: quantity,
      },
    );
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
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
