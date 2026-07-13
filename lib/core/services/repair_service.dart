import 'dart:convert';

import 'package:get/get.dart';

import '../../core/utils/api_response_handler.dart';
import '../../data/models/repair_models.dart';
import '../../data/providers/api_provider.dart';
import '../constants/api_endpoints.dart';

class RepairService extends GetxService {
  RepairService(this._apiProvider);

  final ApiProvider _apiProvider;

  Future<RepairListPage> fetchRepairs({
    required int page,
    required int pageSize,
    String entryNo = '',
    String partyName = '',
    String partyMobile = '',
    String dateFrom = '',
    String dateTo = '',
  }) async {
    final offset = (page - 1) * pageSize;
    final response = await _apiProvider.post(
      ApiEndpoints.repairRead,
      data: <String, dynamic>{
        'offset': offset,
        'search': <String, dynamic>{
          'entry_no': entryNo,
          'date_from': dateFrom,
          'date_to': dateTo,
          'party_name': partyName,
          'party_mobile': partyMobile,
        },
      },
    );

    if (_isEmptyRepairList(response)) {
      return const RepairListPage(
        repairs: <RepairSummaryModel>[],
        hasMore: false,
        totalCount: 0,
      );
    }

    _ensureRepairResponseOk(
      response,
      fallbackMessage: 'Could not load repairs.',
    );

    final data = _dataMap(response);
    final records = _recordList(
      data,
      fallback: response,
    ).map(RepairSummaryModel.fromJson).toList();
    final totalCount = _parseInt(data['total'] ?? response['total']);

    return RepairListPage(
      repairs: records,
      hasMore: totalCount > 0
          ? offset + records.length < totalCount
          : records.length >= pageSize,
      totalCount: totalCount,
    );
  }

  Future<RepairDetailModel> fetchRepairDetail(String repairId) async {
    final response = await _apiProvider.get(
      '${ApiEndpoints.repairDetail}/$repairId',
    );
    _ensureRepairResponseOk(
      response,
      fallbackMessage: 'Could not load repair details.',
    );

    final data = _dataMap(response);
    final summary = RepairSummaryModel.fromJson(data);
    final itemSource =
        data['items'] ??
        data['record'] ??
        data['records'] ??
        response['items'] ??
        response['record'] ??
        response['records'] ??
        const <dynamic>[];
    final items = itemSource is List
        ? itemSource
              .whereType<Map>()
              .map(
                (item) =>
                    RepairItemModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <RepairItemModel>[];

    return RepairDetailModel(summary: summary, items: items, raw: data);
  }

  Future<Map<String, dynamic>> createRepair({
    required String uuid,
    required int entryNo,
    required String entryDate,
    required String partyName,
    required String partyMobile,
    required double advanceAmount,
    required String deliveryDate,
    required String notes,
    required List<RepairDraftItem> items,
  }) {
    return _storeRepair(
      endpoint: ApiEndpoints.repairStore,
      uuid: uuid,
      entryNo: entryNo,
      entryDate: entryDate,
      partyName: partyName,
      partyMobile: partyMobile,
      advanceAmount: advanceAmount,
      deliveryDate: deliveryDate,
      notes: notes,
      items: items,
    );
  }

  Future<Map<String, dynamic>> updateRepair({
    required String repairId,
    required String uuid,
    required int entryNo,
    required String entryDate,
    required String partyName,
    required String partyMobile,
    required double advanceAmount,
    required String deliveryDate,
    required String notes,
    required List<RepairDraftItem> items,
  }) {
    return _storeRepair(
      endpoint: ApiEndpoints.repairStoreById(repairId),
      uuid: uuid,
      entryNo: entryNo,
      entryDate: entryDate,
      partyName: partyName,
      partyMobile: partyMobile,
      advanceAmount: advanceAmount,
      deliveryDate: deliveryDate,
      notes: notes,
      items: items,
    );
  }

  Future<Map<String, dynamic>> _storeRepair({
    required String endpoint,
    required String uuid,
    required int entryNo,
    required String entryDate,
    required String partyName,
    required String partyMobile,
    required double advanceAmount,
    required String deliveryDate,
    required String notes,
    required List<RepairDraftItem> items,
  }) {
    final totalQty = items.fold<int>(0, (sum, item) => sum + item.quantity);
    final totalAmount = items.fold<double>(0, (sum, item) => sum + item.amount);

    final fields = <String, String>{
      'uuid': uuid,
      'entry_no': entryNo.toString(),
      'entry_date': entryDate,
      'party_name': partyName.trim(),
      'party_mobile': partyMobile.trim(),
      'total_qty': totalQty.toString(),
      'total_amt': _amountString(totalAmount),
      'advance_amt': _amountString(advanceAmount),
      'delivery_date': deliveryDate,
      'notes': notes.trim(),
      'items': jsonEncode(items.map((item) => item.toApiJson()).toList()),
    };

    final fileEntries = <MapEntry<String, String>>[];
    for (var index = 0; index < items.length; index++) {
      for (final path in items[index].attachmentPaths) {
        fileEntries.add(MapEntry('attatchment[$index][]', path));
      }
    }

    return _apiProvider.postMultipartFromPaths(
      endpoint,
      fields: fields,
      filePathEntries: fileEntries,
    );
  }

  Future<int> suggestNextEntryNo() async {
    final result = await fetchRepairs(page: 1, pageSize: 20);
    final numbers = result.repairs
        .map((repair) => int.tryParse(repair.entryNo) ?? 0)
        .where((value) => value > 0)
        .toList();
    if (numbers.isEmpty) {
      return 1;
    }
    numbers.sort();
    return numbers.last + 1;
  }

  bool isSuccessResponse(Map<String, dynamic> response) {
    if (response['status'] == true || response['success'] == true) {
      return true;
    }
    return response['code']?.toString() == '200';
  }

  String extractMessage(Map<String, dynamic> response) {
    return (response['message'] ??
            response['msg'] ??
            response['error'] ??
            response['response_message'] ??
            '')
        .toString();
  }

  bool _isEmptyRepairList(Map<String, dynamic> response) {
    final message = extractMessage(response).toLowerCase();
    final data = response['data'];
    return response['status'] == false &&
        message.contains('record not found') &&
        (data is List && data.isEmpty);
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic> response) {
    final dynamic data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return Map<String, dynamic>.from(response);
  }

  List<Map<String, dynamic>> _recordList(
    Map<String, dynamic> data, {
    Map<String, dynamic>? fallback,
  }) {
    final dynamic raw =
        data['record'] ??
        data['records'] ??
        fallback?['record'] ??
        fallback?['records'] ??
        fallback?['data'] ??
        const <dynamic>[];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _amountString(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  void _ensureRepairResponseOk(
    Map<String, dynamic> response, {
    required String fallbackMessage,
  }) {
    final status = response['status'];
    final success = response['success'];
    final code = response['code']?.toString();
    final isOk =
        status == true || success == true || code == null || code == '200';
    if (isOk) {
      return;
    }

    final message = extractMessage(response).trim();
    throw ApiException(message.isEmpty ? fallbackMessage : message);
  }
}
