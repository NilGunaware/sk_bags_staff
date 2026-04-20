import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/services/local_item_sync_service.dart';
import '../../core/services/order_service.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/order_models.dart';

class OrderCreateController extends GetxController {
  final OrderService _orderService = Get.find<OrderService>();
  final LocalItemSyncService _itemSyncService = Get.find<LocalItemSyncService>();

  final formKey = GlobalKey<FormState>();
  final partyNameController = TextEditingController();
  final partyMobileController = TextEditingController();

  final selectedItems = <DraftOrderItem>[].obs;
  final syncWarnings = <String>[].obs;
  final isPreparing = false.obs;
  final isSubmitting = false.obs;
  final nextEntryNo = 1.obs;

  late final String orderUuid;

  @override
  void onInit() {
    super.onInit();
    orderUuid = DateTime.now().millisecondsSinceEpoch.toString();
    prepare();
  }

  @override
  void onClose() {
    partyNameController.dispose();
    partyMobileController.dispose();
    super.onClose();
  }

  Future<void> prepare() async {
    isPreparing.value = true;
    try {
      nextEntryNo.value = await _orderService.suggestNextEntryNo();
    } catch (error) {
      ApiResponseHandler.showErrorSnackbar('Could not prepare order number');
    } finally {
      isPreparing.value = false;
    }
  }

  int get totalQuantity =>
      selectedItems.fold<int>(0, (sum, item) => sum + item.quantity);

  String get entryDate =>
      '${DateTime.now().year}-'
      '${DateTime.now().month.toString().padLeft(2, '0')}-'
      '${DateTime.now().day.toString().padLeft(2, '0')}';

  String get displayEntryDate =>
      '${DateTime.now().day.toString().padLeft(2, '0')}/'
      '${DateTime.now().month.toString().padLeft(2, '0')}/'
      '${DateTime.now().year}';

  Future<MergedItemPage> searchItems({
    required int page,
    required int pageSize,
    required String query,
  }) async {
    final result = await _itemSyncService.searchItems(
      page: page,
      pageSize: pageSize,
      query: query,
    );
    syncWarnings.assignAll(result.warnings);
    return result;
  }

  int selectedQuantityFor(MergedItemModel item) {
    return selectedItems
        .where((entry) => entry.key == item.key)
        .fold<int>(0, (sum, entry) => sum + entry.quantity);
  }

  int maxAllowedFor(MergedItemModel item, {DraftOrderItem? editing}) {
    final alreadySelected = selectedQuantityFor(item);
    final currentEditingQty = editing?.quantity ?? 0;
    return item.totalQuantity - alreadySelected + currentEditingQty;
  }

  void upsertItem(
    MergedItemModel item,
    int quantity, {
    DraftOrderItem? editing,
  }) {
    final maxAllowed = maxAllowedFor(item, editing: editing);
    if (quantity <= 0 || quantity > maxAllowed) {
      ApiResponseHandler.showErrorSnackbar(
        'Quantity must be between 1 and $maxAllowed',
      );
      return;
    }

    final draft = DraftOrderItem(
      itemCode: item.itemCode,
      itemName: item.itemName,
      availableQuantity: item.totalQuantity,
      quantity: quantity,
    );

    final existingIndex = selectedItems.indexWhere(
      (entry) => entry.key == (editing?.key ?? draft.key),
    );

    if (existingIndex >= 0) {
      selectedItems[existingIndex] = draft;
      selectedItems.refresh();
      return;
    }

    selectedItems.add(draft);
  }

  void removeItem(DraftOrderItem item) {
    selectedItems.removeWhere((entry) => entry.key == item.key);
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (selectedItems.isEmpty) {
      ApiResponseHandler.showErrorSnackbar('Add at least one item');
      return;
    }

    isSubmitting.value = true;
    try {
      final response = await _orderService.createOrder(
        uuid: orderUuid,
        entryNo: nextEntryNo.value,
        entryDate: entryDate,
        partyName: partyNameController.text.trim(),
        partyMobile: partyMobileController.text.trim(),
        items: selectedItems.toList(),
      );

      if (_orderService.isSuccessResponse(response)) {
        final message = _orderService.extractMessage(response);
        ApiResponseHandler.showSuccessSnackbar(
          message.isEmpty ? 'Order created successfully' : message,
        );
        Get.back(result: true);
      } else {
        ApiResponseHandler.showErrorSnackbar(
          _orderService.extractMessage(response).isEmpty
              ? 'Could not create order'
              : _orderService.extractMessage(response),
        );
      }
    } finally {
      isSubmitting.value = false;
    }
  }

  List<TextInputFormatter> get mobileFormatters => <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ];
}
