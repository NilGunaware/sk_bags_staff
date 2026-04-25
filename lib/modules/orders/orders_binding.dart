import 'package:get/get.dart';

import '../../core/services/local_item_sync_service.dart';
import '../../core/services/order_service.dart';
import '../../data/providers/api_provider.dart';
import 'order_create_controller.dart';
import 'order_detail_controller.dart';
import 'order_list_controller.dart';

class OrdersDependenciesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ApiProvider>(() => ApiProvider(), fenix: true);
    Get.lazyPut<LocalItemSyncService>(
      () => LocalItemSyncService(),
      fenix: true,
    );
    Get.lazyPut<OrderService>(
      () => OrderService(Get.find<ApiProvider>()),
      fenix: true,
    );
  }
}

class OrderListBinding extends Bindings {
  @override
  void dependencies() {
    OrdersDependenciesBinding().dependencies();
    Get.lazyPut<OrderListController>(() => OrderListController());
  }
}

class OrderDetailBinding extends Bindings {
  @override
  void dependencies() {
    OrdersDependenciesBinding().dependencies();
    Get.lazyPut<OrderDetailController>(() => OrderDetailController());
  }
}

class OrderCreateBinding extends Bindings {
  @override
  void dependencies() {
    OrdersDependenciesBinding().dependencies();
    Get.lazyPut<OrderCreateController>(() => OrderCreateController());
  }
}
