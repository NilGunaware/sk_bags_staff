import 'package:get/get.dart';

import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../../modules/auth/controllers/auth_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<StorageService>(StorageService(), permanent: true);
    Get.put<AuthService>(AuthService(), permanent: true);
    Get.put<AuthController>(
      AuthController(
        Get.find<StorageService>(),
        Get.find<AuthService>(),
      ),
      permanent: true,
    );
  }
}

