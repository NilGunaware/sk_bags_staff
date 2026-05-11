import 'package:get/get.dart';

import '../../data/models/order_models.dart';

class OrderCartService extends GetxService {
  final items = <CartItemModel>[].obs;
  final priceCategories = <PriceCategoryModel>[].obs;
  final selectedPriceCategory = Rxn<PriceCategoryModel>();

  int get lineCount => items.length;

  int get totalQuantity =>
      items.fold<int>(0, (sum, item) => sum + item.quantity);

  double get totalAmount => items.fold<double>(
    0,
    (sum, item) =>
        sum +
        (item.priceFor(selectedPriceCategory.value).finalPrice * item.quantity),
  );

  void setPriceCategories(List<PriceCategoryModel> categories) {
    priceCategories.assignAll(categories);

    final billingCategories = _billingPriceCategories(categories);
    final current = selectedPriceCategory.value;
    if (current != null) {
      PriceCategoryModel? matching;
      for (final item in billingCategories) {
        if (item.categoryNo == current.categoryNo) {
          matching = item;
          break;
        }
      }
      if (matching != null) {
        selectedPriceCategory.value = matching;
        return;
      }
    }

    selectedPriceCategory.value = billingCategories.isNotEmpty
        ? billingCategories.first
        : null;
  }

  void selectPriceCategory(PriceCategoryModel category) {
    selectedPriceCategory.value = category;
  }

  void addFromDetail(MergedItemDetailModel detail, {int quantity = 1}) {
    final maxAllowed = detail.availableOrderQuantity;
    if (maxAllowed <= 0) {
      return;
    }

    final existingIndex = items.indexWhere(
      (item) =>
          item.key == CartItemModel.fromDetail(detail, quantity: quantity).key,
    );

    if (existingIndex >= 0) {
      final existing = items[existingIndex];
      final updatedQuantity = (existing.quantity + quantity).clamp(
        1,
        maxAllowed,
      );
      items[existingIndex] = existing.copyWith(
        quantity: updatedQuantity,
        availableQuantity: maxAllowed,
        serverQuantities: detail.serverQuantities,
        prices: detail.prices,
        imageUrl: detail.image?.url,
        imageUrls: detail.imageUrls,
      );
      items.refresh();
      return;
    }

    items.add(
      CartItemModel.fromDetail(detail, quantity: quantity.clamp(1, maxAllowed)),
    );
  }

  void updateQuantity(CartItemModel item, int quantity) {
    final index = items.indexWhere((entry) => entry.key == item.key);
    if (index < 0) {
      return;
    }

    final clamped = quantity.clamp(1, item.availableQuantity);
    items[index] = item.copyWith(quantity: clamped);
    items.refresh();
  }

  void removeItem(CartItemModel item) {
    items.removeWhere((entry) => entry.key == item.key);
  }

  void clear() => items.clear();
}

List<PriceCategoryModel> _billingPriceCategories(
  List<PriceCategoryModel> categories,
) {
  final visible = categories
      .where((category) => category.isPrimaryBusinessPrice)
      .toList();
  const order = <String>['A', 'W', 'C', 'H'];
  visible.sort(
    (a, b) =>
        order.indexOf(a.displayCode).compareTo(order.indexOf(b.displayCode)),
  );
  return visible;
}
