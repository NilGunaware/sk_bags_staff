import 'package:get/get.dart';

import '../../core/services/local_item_sync_service.dart';
import '../../core/services/order_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/order_models.dart';

class OrderDetailController extends GetxController {
  final OrderService _orderService = Get.find<OrderService>();
  final LocalItemSyncService _itemSyncService =
      Get.find<LocalItemSyncService>();
  final StorageService _storageService = Get.find<StorageService>();

  final order = Rxn<OrderSummaryModel>();
  final detail = Rxn<OrderDetailModel>();
  final isLoading = false.obs;
  final isHydratingItems = false.obs;
  final errorMessage = RxnString();
  final itemDetailWarnings = <String>[].obs;
  bool wasUpdated = false;

  @override
  void onInit() {
    super.onInit();
    final argument = Get.arguments;
    if (argument is OrderSummaryModel) {
      order.value = argument;
      fetchDetail();
    }
  }

  Future<void> fetchDetail() async {
    final currentOrder = order.value;
    if (currentOrder == null || currentOrder.id.isEmpty) {
      return;
    }

    isLoading.value = true;
    try {
      errorMessage.value = null;
      itemDetailWarnings.clear();
      final loadedDetail = await _orderService.fetchOrderDetail(
        currentOrder.id,
      );
      detail.value = _applyCachedPriceSelection(loadedDetail);
      await hydrateItemDetails();
    } catch (error) {
      errorMessage.value = _friendlyOrderDetailMessage(error);
      ApiResponseHandler.showErrorSnackbar('Could not load order details');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> hydrateItemDetails() async {
    final currentDetail = detail.value;
    if (currentDetail == null || currentDetail.items.isEmpty) {
      return;
    }

    isHydratingItems.value = true;
    final warnings = <String>[];
    final hydratedItems = <OrderItemModel>[];

    try {
      for (final item in currentDetail.items) {
        final lookup = item.itemCode.trim().isNotEmpty
            ? item.itemCode.trim()
            : item.itemName.trim();
        if (lookup.isEmpty) {
          warnings.add('Could not load image for item without code.');
          hydratedItems.add(item);
          continue;
        }

        try {
          final itemDetail = await _itemSyncService.fetchItemDetailByLookup(
            lookup,
          );
          hydratedItems.add(item.copyWith(itemDetails: itemDetail));
          warnings.addAll(itemDetail.warnings);
        } catch (_) {
          warnings.add(
            'Image and live details unavailable for ${item.itemCode.isEmpty ? item.itemName : item.itemCode}.',
          );
          hydratedItems.add(item);
        }
      }

      detail.value = currentDetail.copyWith(items: hydratedItems);

      final uniqueWarnings = <String>[];
      for (final warning in warnings) {
        if (!uniqueWarnings.contains(warning)) {
          uniqueWarnings.add(warning);
        }
      }
      itemDetailWarnings.assignAll(uniqueWarnings);
    } finally {
      isHydratingItems.value = false;
    }
  }

  OrderDetailModel _applyCachedPriceSelection(OrderDetailModel loadedDetail) {
    final selectedCategory =
        _storageService.readOrderPriceSelection(
          _orderSelectionKeys(loadedDetail.summary),
        ) ??
        loadedDetail.selectedPriceCategory ??
        loadedDetail.summary.selectedPriceCategory;

    if (selectedCategory == null) {
      return loadedDetail;
    }

    return loadedDetail.copyWith(selectedPriceCategory: selectedCategory);
  }

  Iterable<String> _orderSelectionKeys(OrderSummaryModel summary) sync* {
    if (summary.id.trim().isNotEmpty) {
      yield 'id:${summary.id.trim()}';
    }
    if (summary.uuid.trim().isNotEmpty) {
      yield 'uuid:${summary.uuid.trim()}';
    }
    if (summary.entryNo.trim().isNotEmpty) {
      yield 'entry:${summary.entryNo.trim()}';
    }
  }

  String _friendlyOrderDetailMessage(Object error) {
    final text = error.toString().trim();
    if (text.isEmpty) {
      return 'Order details are unavailable right now. Please try again.';
    }

    final lower = text.toLowerCase();
    if (lower.contains('socket') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection') ||
        lower.contains('timeout')) {
      return 'Order details are unavailable right now. Please check your connection and try again.';
    }

    if (lower.contains('invalid response') ||
        lower.contains('unexpected character') ||
        lower.contains('formatexception')) {
      return 'The order service returned an invalid response. Please try again shortly.';
    }

    if (lower.contains('exception') ||
        lower.contains('sql') ||
        lower.contains('syntax') ||
        lower.contains('trace') ||
        lower.contains('stack')) {
      return 'Order details are unavailable right now. Please try again shortly.';
    }

    return text;
  }
}
