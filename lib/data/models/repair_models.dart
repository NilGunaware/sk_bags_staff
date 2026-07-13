class RepairListPage {
  const RepairListPage({
    required this.repairs,
    required this.hasMore,
    required this.totalCount,
  });

  final List<RepairSummaryModel> repairs;
  final bool hasMore;
  final int totalCount;
}

class RepairSummaryModel {
  const RepairSummaryModel({
    required this.id,
    required this.uuid,
    required this.entryNo,
    required this.entryDate,
    required this.partyName,
    required this.partyMobile,
    required this.totalQty,
    required this.totalAmount,
    required this.advanceAmount,
    required this.deliveryDate,
    required this.notes,
    required this.raw,
  });

  final String id;
  final String uuid;
  final String entryNo;
  final String entryDate;
  final String partyName;
  final String partyMobile;
  final int totalQty;
  final double totalAmount;
  final double advanceAmount;
  final String deliveryDate;
  final String notes;
  final Map<String, dynamic> raw;

  double get balanceAmount => totalAmount - advanceAmount;

  factory RepairSummaryModel.fromJson(Map<String, dynamic> json) {
    return RepairSummaryModel(
      id: _stringValue(json['id']),
      uuid: _stringValue(json['uuid']),
      entryNo: _stringValue(json['entry_no'] ?? json['entryNo']),
      entryDate: _stringValue(json['entry_date'] ?? json['entryDate']),
      partyName: _stringValue(json['party_name'] ?? json['partyName']),
      partyMobile: _stringValue(
        json['party_mobile'] ?? json['partyMobile'] ?? json['mobile_no'],
      ),
      totalQty: _parseInt(json['total_qty'] ?? json['totalQty'] ?? json['qty']),
      totalAmount: _parseDouble(
        json['total_amt'] ?? json['totalAmount'] ?? json['amount'],
      ),
      advanceAmount: _parseDouble(
        json['advance_amt'] ?? json['advanceAmount'] ?? json['advance'],
      ),
      deliveryDate: _stringValue(json['delivery_date'] ?? json['deliveryDate']),
      notes: _stringValue(json['notes'] ?? json['note']),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

class RepairDetailModel {
  const RepairDetailModel({
    required this.summary,
    required this.items,
    required this.raw,
  });

  final RepairSummaryModel summary;
  final List<RepairItemModel> items;
  final Map<String, dynamic> raw;
}

class RepairItemModel {
  const RepairItemModel({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.rate,
    required this.amount,
    required this.instruction,
    required this.attachments,
    required this.raw,
  });

  final String id;
  final String itemName;
  final int quantity;
  final double rate;
  final double amount;
  final String instruction;
  final List<String> attachments;
  final Map<String, dynamic> raw;

  factory RepairItemModel.fromJson(Map<String, dynamic> json) {
    return RepairItemModel(
      id: _stringValue(json['id']),
      itemName: _stringValue(json['item_name'] ?? json['itemName']),
      quantity: _parseInt(json['qty'] ?? json['quantity']),
      rate: _parseDouble(json['rate']),
      amount: _parseDouble(json['amt'] ?? json['amount']),
      instruction: _stringValue(
        json['instruction'] ?? json['instructions'] ?? json['notes'],
      ),
      attachments: _parseAttachments(
        json['attatch_data'] ??
            json['attach_data'] ??
            json['attachment'] ??
            json['attachments'],
      ),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

class RepairDraftItem {
  RepairDraftItem({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.rate,
    required this.instruction,
    required this.attachmentPaths,
    this.existingAttachments = const <String>[],
  });

  final String id;
  final String itemName;
  final int quantity;
  final double rate;
  final String instruction;
  final List<String> attachmentPaths;
  final List<String> existingAttachments;

  double get amount => quantity * rate;

  Map<String, dynamic> toApiJson() {
    return <String, dynamic>{
      'id': id.trim().isEmpty ? 0 : id,
      'item_name': itemName.trim(),
      'qty': quantity,
      'rate': rate,
      'amt': amount,
      'instruction': instruction.trim(),
      'attatch_data': existingAttachments,
    };
  }

  RepairDraftItem copyWith({
    String? id,
    String? itemName,
    int? quantity,
    double? rate,
    String? instruction,
    List<String>? attachmentPaths,
    List<String>? existingAttachments,
  }) {
    return RepairDraftItem(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      instruction: instruction ?? this.instruction,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      existingAttachments: existingAttachments ?? this.existingAttachments,
    );
  }
}

String _stringValue(dynamic value) => value?.toString() ?? '';

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  final text = value?.toString() ?? '';
  return int.tryParse(text) ?? double.tryParse(text)?.toInt() ?? 0;
}

double _parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _parseAttachments(dynamic value) {
  if (value is List) {
    return value
        .map((item) {
          if (item is Map) {
            return _normalizeAttachment(
              item['url'] ??
                  item['path'] ??
                  item['file'] ??
                  item['image'] ??
                  item['att_path'] ??
                  item['attatchment'] ??
                  item['attachment'] ??
                  item['attatchment_url'] ??
                  item['attachment_url'] ??
                  item['file_url'] ??
                  item['file_path'] ??
                  item['name'],
            );
          }
          return _normalizeAttachment(item);
        })
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
  final single = _normalizeAttachment(value);
  return single.trim().isEmpty ? <String>[] : <String>[single];
}

String _normalizeAttachment(dynamic value) {
  final text = _stringValue(value).trim();
  if (text.isEmpty) return '';
  if (text.startsWith('http://') || text.startsWith('https://')) {
    return text;
  }
  if (text.startsWith('/')) {
    return 'https://interlinkpos.com$text';
  }
  return 'https://interlinkpos.com/sk_bags/$text';
}
