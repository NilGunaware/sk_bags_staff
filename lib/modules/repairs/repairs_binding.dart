import 'package:get/get.dart';

import '../../core/services/repair_service.dart';
import '../../data/providers/api_provider.dart';
import 'repair_create_controller.dart';
import 'repair_detail_controller.dart';
import 'repair_list_controller.dart';

class RepairsDependenciesBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ApiProvider>()) {
      Get.lazyPut<ApiProvider>(() => ApiProvider(), fenix: true);
    }
    if (!Get.isRegistered<RepairService>()) {
      Get.lazyPut<RepairService>(
        () => RepairService(Get.find<ApiProvider>()),
        fenix: true,
      );
    }
  }
}

class RepairListBinding extends Bindings {
  @override
  void dependencies() {
    RepairsDependenciesBinding().dependencies();
    Get.lazyPut<RepairListController>(() => RepairListController());
  }
}

class RepairCreateBinding extends Bindings {
  @override
  void dependencies() {
    RepairsDependenciesBinding().dependencies();
    Get.lazyPut<RepairCreateController>(() => RepairCreateController());
  }
}

class RepairDetailBinding extends Bindings {
  @override
  void dependencies() {
    RepairsDependenciesBinding().dependencies();
    Get.lazyPut<RepairDetailController>(() => RepairDetailController());
  }
}
