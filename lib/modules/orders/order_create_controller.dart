import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/services/local_item_sync_service.dart';
import '../../core/services/order_service.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/order_models.dart';

class OrderCreateController extends GetxController {
  final OrderService _orderService = Get.find<OrderService>();
  final LocalItemSyncService _itemSyncService =
      Get.find<LocalItemSyncService>();

  final formKey = GlobalKey<FormState>();
  final partyNameController = TextEditingController();
  final partyMobileController = TextEditingController();

  final selectedItems = <DraftOrderItem>[].obs;
  final cartItems = <CartItemModel>[].obs;
  final priceCategories = <PriceCategoryModel>[].obs;
  final selectedPriceCategory = Rxn<PriceCategoryModel>();
  final syncWarnings = <String>[].obs;
  final isPreparing = false.obs;
  final isSubmitting = false.obs;
  final isLookingUpItem = false.obs;
  final isHydratingOrderItems = false.obs;
  final nextEntryNo = 1.obs;
  final itemIdsByKey = <String, String>{};

  late final String orderUuid;
  bool isEditMode = false;
  String editingOrderId = '';
  String editingEntryDate = '';

  @override
  void onInit() {
    super.onInit();
    final argument = Get.arguments;
    if (argument is OrderDetailModel) {
      _configureForEdit(argument);
    } else {
      orderUuid = DateTime.now().millisecondsSinceEpoch.toString();
    }
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
      try {
        await loadPriceCategories();
      } catch (_) {
        priceCategories.clear();
        selectedPriceCategory.value = null;
      }
      if (!isEditMode) {
        nextEntryNo.value = await _orderService.suggestNextEntryNo();
      }
      if (isEditMode) {
        await hydrateOrderItemsForEdit();
      }
    } catch (error) {
      ApiResponseHandler.showErrorSnackbar(
        isEditMode
            ? 'Could not prepare order update'
            : 'Could not prepare order number',
      );
    } finally {
      isPreparing.value = false;
    }
  }

  Future<void> loadPriceCategories() async {
    final categories = await _itemSyncService.fetchPriceCategories();
    final visible = categories
        .where((category) => category.isPrimaryBusinessPrice)
        .toList();
    const order = <String>['A', 'W', 'C', 'H'];
    visible.sort(
      (a, b) =>
          order.indexOf(a.displayCode).compareTo(order.indexOf(b.displayCode)),
    );
    priceCategories.assignAll(visible);
    selectedPriceCategory.value = visible.isNotEmpty ? visible.first : null;
  }

  void selectPriceCategory(PriceCategoryModel category) {
    selectedPriceCategory.value = category;
  }

  Future<void> hydrateOrderItemsForEdit() async {
    if (!isEditMode || cartItems.isEmpty) {
      return;
    }

    isHydratingOrderItems.value = true;
    final warnings = <String>[];
    try {
      for (final currentItem in cartItems.toList()) {
        final lookup = currentItem.itemCode.trim().isNotEmpty
            ? currentItem.itemCode.trim()
            : currentItem.itemName.trim();
        if (lookup.isEmpty) {
          warnings.add(
            'Could not load details for an order item without code.',
          );
          continue;
        }

        try {
          final detail = await _itemSyncService.fetchItemDetailByLookup(lookup);
          _mergeHydratedDetailIntoCart(currentItem, detail);
          warnings.addAll(detail.warnings);
        } catch (_) {
          warnings.add(
            'Could not load live details and prices for ${currentItem.itemCode.isEmpty ? currentItem.itemName : currentItem.itemCode}.',
          );
        }
      }
      final uniqueWarnings = <String>[];
      for (final warning in warnings) {
        if (!uniqueWarnings.contains(warning)) {
          uniqueWarnings.add(warning);
        }
      }
      syncWarnings.assignAll(uniqueWarnings);
      _syncDraftItemsFromCart();
    } finally {
      isHydratingOrderItems.value = false;
    }
  }

  int get totalQuantity =>
      cartItems.fold<int>(0, (sum, item) => sum + item.quantity);

  int get lineCount => cartItems.length;

  double get totalAmount => cartItems.fold<double>(
    0,
    (sum, item) =>
        sum +
        (item.priceFor(selectedPriceCategory.value).finalPrice * item.quantity),
  );

  String get entryDate => isEditMode && editingEntryDate.trim().isNotEmpty
      ? editingEntryDate.trim()
      : '${DateTime.now().year}-'
            '${DateTime.now().month.toString().padLeft(2, '0')}-'
            '${DateTime.now().day.toString().padLeft(2, '0')}';

  String get displayEntryDate =>
      isEditMode && editingEntryDate.trim().isNotEmpty
      ? editingEntryDate.trim()
      : '${DateTime.now().day.toString().padLeft(2, '0')}/'
            '${DateTime.now().month.toString().padLeft(2, '0')}/'
            '${DateTime.now().year}';

  String get screenTitle => isEditMode ? 'Update Order' : 'Create Order';

  String get heroTitle => isEditMode ? 'Editing Order' : 'Order Draft';

  String get submitLabel => isEditMode ? 'Update Order' : 'Create Order';

  String get submittingLabel => isEditMode ? 'Updating...' : 'Submitting...';

  String get preparingLabel =>
      isEditMode ? 'Preparing Update...' : 'Preparing Order...';

  void _configureForEdit(OrderDetailModel detail) {
    final summary = detail.summary;
    isEditMode = true;
    editingOrderId = summary.id;
    editingEntryDate = summary.entryDate;
    orderUuid = summary.uuid.trim().isEmpty
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : summary.uuid;
    nextEntryNo.value = int.tryParse(summary.entryNo) ?? 0;
    partyNameController.text = summary.partyName;
    partyMobileController.text = summary.partyMobile;
    final draftItems = detail.items
        .map(
          (item) => DraftOrderItem(
            id: item.id,
            itemCode: item.itemCode,
            itemName: item.itemName,
            availableQuantity: item.quantity <= 0 ? 999999 : item.quantity,
            quantity: item.quantity <= 0 ? 1 : item.quantity,
          ),
        )
        .toList();
    selectedItems.assignAll(draftItems);
    cartItems.assignAll(
      draftItems.map((item) {
        final key = _draftKey(item.itemCode, item.itemName);
        itemIdsByKey[key] = item.id;
        if (item.itemCode.trim().isNotEmpty) {
          itemIdsByKey[item.itemCode.trim()] = item.id;
        }
        OrderItemModel? originalOrderItem;
        for (final orderItem in detail.items) {
          final sameId = item.id.isNotEmpty && orderItem.id == item.id;
          final sameItem =
              _draftKey(orderItem.itemCode, orderItem.itemName) == key;
          if (sameId || sameItem) {
            originalOrderItem = orderItem;
            break;
          }
        }
        final itemDetails = originalOrderItem?.itemDetails;
        if (itemDetails != null) {
          final availableWithCurrent =
              itemDetails.availableOrderQuantity + item.quantity;
          final safeAvailable = availableWithCurrent < item.quantity
              ? item.quantity
              : availableWithCurrent;
          return CartItemModel.fromDetail(
            itemDetails,
            quantity: item.quantity,
          ).copyWith(availableQuantity: safeAvailable);
        }
        return CartItemModel(
          itemCode: item.itemCode,
          itemName: item.itemName,
          itemGroup: '',
          quantity: item.quantity,
          availableQuantity: 999999,
          serverQuantities: const <String, double>{},
          prices: const <ItemPriceModel>[],
        );
      }),
    );
  }

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
    syncWarnings.assignAll(result.items.isEmpty ? result.warnings : <String>[]);
    return result;
  }

  MergedItemPage filterLoadedItems({
    required Iterable<MergedItemModel> items,
    required int page,
    required int pageSize,
    required String query,
    List<String> warnings = const <String>[],
    bool forceHasMore = false,
  }) {
    return _itemSyncService.filterLoadedItems(
      items: items,
      page: page,
      pageSize: pageSize,
      query: query,
      warnings: warnings,
      forceHasMore: forceHasMore,
    );
  }

  int selectedQuantityFor(MergedItemModel item) {
    return selectedItems
        .where((entry) => entry.key == item.key)
        .fold<int>(0, (sum, entry) => sum + entry.quantity);
  }

  int maxAllowedFor(MergedItemModel item, {DraftOrderItem? editing}) {
    return 999999;
  }

  void upsertItem(
    MergedItemModel item,
    int quantity, {
    DraftOrderItem? editing,
  }) {
    if (quantity <= 0) {
      ApiResponseHandler.showErrorSnackbar('Quantity must be greater than 0');
      return;
    }

    final draft = DraftOrderItem(
      id: editing?.id ?? '',
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
    cartItems.removeWhere(
      (entry) => _draftKey(entry.itemCode, entry.itemName) == item.key,
    );
  }

  Future<void> addItemByLookup(String lookup) async {
    final trimmedLookup = lookup.trim();
    if (trimmedLookup.isEmpty) {
      ApiResponseHandler.showErrorSnackbar('Enter a QR code or item code');
      return;
    }

    isLookingUpItem.value = true;
    try {
      final detail = await _itemSyncService.fetchItemDetailByLookup(
        trimmedLookup,
      );
      addCartItemFromDetail(detail);
      ApiResponseHandler.showSuccessSnackbar('Item added to order');
    } catch (error) {
      ApiResponseHandler.showErrorSnackbar(_friendlyLookupMessage(error));
    } finally {
      isLookingUpItem.value = false;
    }
  }

  void addCartItemFromDetail(MergedItemDetailModel detail, {int quantity = 1}) {
    final safeQuantity = quantity <= 0 ? 1 : quantity;

    final incoming = CartItemModel.fromDetail(detail, quantity: safeQuantity);
    final existingIndex = cartItems.indexWhere(
      (item) => item.key == incoming.key,
    );

    if (existingIndex >= 0) {
      final existing = cartItems[existingIndex];
      final updatedQuantity = existing.quantity + safeQuantity;
      cartItems[existingIndex] = existing.copyWith(
        quantity: updatedQuantity,
        availableQuantity: detail.availableOrderQuantity,
        itemGroup: detail.itemGroup,
        qrCode: detail.qrCode,
        hsnCode: detail.hsnCode,
        imageUrl: detail.image?.url,
        imageUrls: detail.imageUrls,
        serverQuantities: detail.serverQuantities,
        prices: detail.prices,
      );
      cartItems.refresh();
      _syncDraftItemsFromCart();
      return;
    }

    cartItems.add(incoming);
    _syncDraftItemsFromCart();
  }

  void _mergeHydratedDetailIntoCart(
    CartItemModel currentItem,
    MergedItemDetailModel detail,
  ) {
    final index = cartItems.indexWhere((entry) => entry.key == currentItem.key);
    if (index < 0) {
      return;
    }

    final current = cartItems[index];
    final oldKey = _draftKey(current.itemCode, current.itemName);
    final oldLineId =
        itemIdsByKey[oldKey] ?? itemIdsByKey[current.itemCode.trim()];
    final hydratedKey = _draftKey(detail.itemCode, detail.itemName);
    if (oldLineId != null && oldLineId.isNotEmpty) {
      itemIdsByKey[hydratedKey] = oldLineId;
      if (detail.itemCode.trim().isNotEmpty) {
        itemIdsByKey[detail.itemCode.trim()] = oldLineId;
      }
    }

    cartItems[index] = CartItemModel.fromDetail(
      detail,
      quantity: current.quantity,
    );
    cartItems.refresh();
  }

  void updateCartItemQuantity(CartItemModel item, int quantity) {
    final index = cartItems.indexWhere((entry) => entry.key == item.key);
    if (index < 0) {
      return;
    }

    final safeQuantity = quantity <= 0 ? 1 : quantity;
    cartItems[index] = item.copyWith(quantity: safeQuantity);
    cartItems.refresh();
    _syncDraftItemsFromCart();
  }

  void removeCartItem(CartItemModel item) {
    cartItems.removeWhere((entry) => entry.key == item.key);
    selectedItems.removeWhere(
      (entry) => _draftKey(item.itemCode, item.itemName) == entry.key,
    );
  }

  ItemPriceModel selectedPriceForCartItem(CartItemModel item) {
    return item.priceFor(selectedPriceCategory.value);
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }
    _syncDraftItemsFromCart();

    if (selectedItems.isEmpty) {
      ApiResponseHandler.showErrorSnackbar('Add at least one item');
      return;
    }
    if (isEditMode && editingOrderId.trim().isEmpty) {
      ApiResponseHandler.showErrorSnackbar('Order id is missing');
      return;
    }

    isSubmitting.value = true;
    try {
      final response = isEditMode
          ? await _orderService.updateOrder(
              orderId: editingOrderId,
              uuid: orderUuid,
              entryNo: nextEntryNo.value,
              entryDate: entryDate,
              partyName: partyNameController.text.trim(),
              partyMobile: partyMobileController.text.trim(),
              items: selectedItems.toList(),
            )
          : await _orderService.createOrder(
              uuid: orderUuid,
              entryNo: nextEntryNo.value,
              entryDate: entryDate,
              partyName: partyNameController.text.trim(),
              partyMobile: partyMobileController.text.trim(),
              items: selectedItems.toList(),
            );

      if (_orderService.isSuccessResponse(response)) {
        final message = _orderService.extractMessage(response);
        Get.back<Map<String, dynamic>>(
          result: <String, dynamic>{
            if (isEditMode) 'updated': true else 'created': true,
            'message': message.isEmpty
                ? isEditMode
                      ? 'Order updated successfully'
                      : 'Order created successfully'
                : message,
          },
        );
      } else {
        ApiResponseHandler.showErrorSnackbar(
          _orderService.extractMessage(response).isEmpty
              ? isEditMode
                    ? 'Could not update order'
                    : 'Could not create order'
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

  void _syncDraftItemsFromCart() {
    selectedItems.assignAll(
      cartItems.map((item) {
        final key = _draftKey(item.itemCode, item.itemName);
        return DraftOrderItem(
          id: itemIdsByKey[key] ?? itemIdsByKey[item.itemCode.trim()] ?? '',
          itemCode: item.itemCode,
          itemName: item.itemName,
          availableQuantity: item.availableQuantity,
          quantity: item.quantity,
        );
      }),
    );
  }

  String _draftKey(String itemCode, String itemName) =>
      '${itemCode.trim()}|${itemName.trim()}';

  String _friendlyLookupMessage(Object error) {
    final text = error.toString().trim();
    if (text.isEmpty) {
      return 'Item details are unavailable right now.';
    }

    final lower = text.toLowerCase();
    if (lower.contains('no item matched') || lower.contains('not found')) {
      return 'No item matched this QR code.';
    }
    if (lower.contains('socket') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection') ||
        lower.contains('timeout') ||
        lower.contains('unavailable')) {
      return 'Item servers are unavailable right now. Please try again.';
    }
    return text.replaceFirst('Exception: ', '');
  }
}
