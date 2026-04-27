import 'package:get/get.dart';
import '../../core/services/local_item_sync_service.dart';
import '../../core/services/order_service.dart';
import '../../data/providers/api_provider.dart';

import 'home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ApiProvider>()) {
      Get.lazyPut<ApiProvider>(() => ApiProvider(), fenix: true);
    }
    if (!Get.isRegistered<LocalItemSyncService>()) {
      Get.lazyPut<LocalItemSyncService>(
        () => LocalItemSyncService(),
        fenix: true,
      );
    }
    if (!Get.isRegistered<OrderService>()) {
      Get.lazyPut<OrderService>(
        () => OrderService(Get.find<ApiProvider>()),
        fenix: true,
      );
    }
    Get.lazyPut<HomeController>(() => HomeController());
  }
}
