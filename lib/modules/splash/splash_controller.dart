import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../auth/controllers/auth_controller.dart';

class SplashController extends GetxController {
  final AuthController _authController = Get.find<AuthController>();

  @override
  void onReady() {
    super.onReady();
    _navigate();
  }

  Future<void> _navigate() async {
    await _authController.hydrateSession();
    await Future.delayed(const Duration(milliseconds: 1200));
    if (_authController.isLoggedIn.isTrue) {
      Get.offAllNamed(Routes.home);
    } else {
      Get.offAllNamed(Routes.login);
    }
  }
}

