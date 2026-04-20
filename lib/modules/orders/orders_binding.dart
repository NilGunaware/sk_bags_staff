import 'package:get/get.dart';

import '../../core/services/local_item_sync_service.dart';
import '../../core/services/order_service.dart';
import '../../data/providers/api_provider.dart';
import 'order_create_controller.dart';
import 'order_detail_controller.dart';
import 'order_list_controller.dart';

class OrdersBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ApiProvider>(() => ApiProvider(), fenix: true);
    Get.lazyPut<LocalItemSyncService>(() => LocalItemSyncService(), fenix: true);
    Get.lazyPut<OrderService>(
      () => OrderService(Get.find<ApiProvider>()),
      fenix: true,
    );
    Get.lazyPut<OrderListController>(() => OrderListController());
    Get.lazyPut<OrderDetailController>(() => OrderDetailController());
    Get.lazyPut<OrderCreateController>(() => OrderCreateController());
  }
}
