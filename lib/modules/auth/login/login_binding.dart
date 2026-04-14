import 'package:get/get.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/providers/api_provider.dart';
import 'login_controller.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ApiProvider>(() => ApiProvider(), fenix: true);
    Get.lazyPut<AuthRepository>(
      () => AuthRepository(Get.find<ApiProvider>()),
      fenix: true,
    );
    Get.lazyPut<LoginController>(
      () => LoginController(Get.find<AuthRepository>()),
    );
  }
}

