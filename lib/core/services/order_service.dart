import 'package:get/get.dart';

import '../../core/utils/api_response_handler.dart';
import '../../data/models/order_models.dart';
import '../../data/providers/api_provider.dart';
import '../constants/api_endpoints.dart';

class OrderService extends GetxService {
  OrderService(this._apiProvider);

  final ApiProvider _apiProvider;

  Future<OrderListPage> fetchOrders({
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
      ApiEndpoints.orderRead,
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
    _ensureOrderResponseOk(response, fallbackMessage: 'Could not load orders.');

    final data = _dataMap(response);
    final records = _recordList(
      data,
      fallback: response,
    ).map(OrderSummaryModel.fromJson).toList();
    final totalCount = _parseInt(data['total'] ?? response['total']);

    return OrderListPage(
      orders: records,
      hasMore: totalCount > 0
          ? offset + records.length < totalCount
          : records.length >= pageSize,
      totalCount: totalCount,
    );
  }

  Future<OrderDetailModel> fetchOrderDetail(String orderId) async {
    final response = await _apiProvider.get(
      '${ApiEndpoints.orderDetail}/$orderId',
      queryParameters: const <String, dynamic>{
        'itemPage': 1,
        'itemPageSize': 1000,
      },
    );
    _ensureOrderResponseOk(
      response,
      fallbackMessage: 'Could not load order details.',
    );
    final data = _dataMap(response);

    final summary = OrderSummaryModel.fromJson(data);
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
                    OrderItemModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <OrderItemModel>[];

    return OrderDetailModel(summary: summary, items: items, raw: data);
  }

  Future<Map<String, dynamic>> createOrder({
    required String uuid,
    required int entryNo,
    required String entryDate,
    required String partyName,
    required String partyMobile,
    required List<DraftOrderItem> items,
    PriceCategoryModel? selectedPriceCategory,
  }) {
    return _apiProvider.post(
      ApiEndpoints.orderStore,
      data: _orderPayload(
        uuid: uuid,
        entryNo: entryNo,
        entryDate: entryDate,
        partyName: partyName,
        partyMobile: partyMobile,
        items: items,
        selectedPriceCategory: selectedPriceCategory,
      ),
    );
  }

  Future<Map<String, dynamic>> updateOrder({
    required String orderId,
    required String uuid,
    required int entryNo,
    required String entryDate,
    required String partyName,
    required String partyMobile,
    required List<DraftOrderItem> items,
    PriceCategoryModel? selectedPriceCategory,
  }) {
    return _apiProvider.post(
      ApiEndpoints.orderStoreById(orderId),
      data: _orderPayload(
        uuid: uuid,
        entryNo: entryNo,
        entryDate: entryDate,
        partyName: partyName,
        partyMobile: partyMobile,
        items: items,
        selectedPriceCategory: selectedPriceCategory,
      ),
    );
  }

  Future<int> suggestNextEntryNo() async {
    final result = await fetchOrders(page: 1, pageSize: 20);
    final numbers = result.orders
        .map((order) => int.tryParse(order.entryNo) ?? 0)
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

  Map<String, dynamic> _orderPayload({
    required String uuid,
    required int entryNo,
    required String entryDate,
    required String partyName,
    required String partyMobile,
    required List<DraftOrderItem> items,
    PriceCategoryModel? selectedPriceCategory,
  }) {
    final pricePayload = _priceCategoryPayload(selectedPriceCategory);
    return <String, dynamic>{
      'uuid': uuid,
      'entry_no': entryNo,
      'entry_date': entryDate,
      'party_name': partyName,
      'party_mobile': partyMobile,
      ...pricePayload,
      'total_qty': items
          .fold<int>(0, (sum, item) => sum + item.quantity)
          .toString(),
      'items': items.map((item) {
        final itemPriceCategory =
            item.selectedPriceCategory ?? selectedPriceCategory;
        final itemPricePayload = _priceCategoryPayload(itemPriceCategory);
        return <String, dynamic>{
          'id': item.id.isEmpty ? 0 : item.id,
          'item_code': item.itemCode,
          'item_name': item.itemName,
          'qty': item.quantity,
          ...itemPricePayload,
          if (item.selectedFinalPrice != null)
            'selected_final_price': item.selectedFinalPrice,
        };
      }).toList(),
    };
  }

  Map<String, dynamic> _priceCategoryPayload(PriceCategoryModel? category) {
    if (category == null) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{
      'price_category_no': category.categoryNo,
      'price_category_code': category.categoryCode,
      'price_category_name': category.displayName,
      'price_slot_id': category.slotId,
      'selected_price_category': category.toSelectionJson(),
    };
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

  void _ensureOrderResponseOk(
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
