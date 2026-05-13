import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../data/models/order_models.dart';

class StorageKeys {
  static const String user = 'user';
  static const String orderPriceSelections = 'order_price_selections';
}

class StorageService extends GetxService {
  StorageService();

  final GetStorage _box = GetStorage();

  Future<void> saveUser(Map<String, dynamic> user) async {
    await _box.write(StorageKeys.user, user);
  }

  Map<String, dynamic>? readUser() {
    final value = _box.read(StorageKeys.user);
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Future<void> clearUser() async {
    await _box.remove(StorageKeys.user);
  }

  Future<void> saveOrderPriceSelection({
    required Iterable<String> keys,
    required PriceCategoryModel? category,
  }) async {
    if (category == null) {
      return;
    }

    final storageKeys = keys
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toSet();
    if (storageKeys.isEmpty) {
      return;
    }

    final existing = _readOrderPriceSelections();
    for (final key in storageKeys) {
      existing[key] = category.toSelectionJson();
    }
    await _box.write(StorageKeys.orderPriceSelections, existing);
  }

  PriceCategoryModel? readOrderPriceSelection(Iterable<String> keys) {
    final existing = _readOrderPriceSelections();
    for (final key in keys) {
      final value = existing[key.trim()];
      if (value is Map) {
        final category = PriceCategoryModel.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (category.categoryNo > 0 || category.categoryCode.isNotEmpty) {
          return category;
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _readOrderPriceSelections() {
    final value = _box.read(StorageKeys.orderPriceSelections);
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }
}
