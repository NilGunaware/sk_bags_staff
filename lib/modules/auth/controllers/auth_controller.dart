import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/storage_service.dart';

class AuthController extends GetxController {
  AuthController(this._storageService, this._authService);

  final StorageService _storageService;
  final AuthService _authService;

  final Rxn<Map<String, dynamic>> user = Rxn<Map<String, dynamic>>();
  final RxBool isLoggedIn = false.obs;

  Future<bool> hydrateSession() async {
    final savedUser = _storageService.readUser();
    if (savedUser != null) {
      user.value = savedUser;
      isLoggedIn.value = true;
      final token = savedUser['token']?.toString();
      if (token != null && token.isNotEmpty) {
        await _authService.saveTokens(token);
      }
      return true;
    }
    user.value = null;
    isLoggedIn.value = false;
    return false;
  }

  Future<void> saveSession(Map<String, dynamic> userData) async {
    await _storageService.saveUser(userData);
    final token = userData['token']?.toString();
    if (token != null && token.isNotEmpty) {
      await _authService.saveTokens(token);
    }
    user.value = userData;
    isLoggedIn.value = true;
  }

  Future<void> clearSession() async {
    await _storageService.clearUser();
    await _authService.clearTokens();
    user.value = null;
    isLoggedIn.value = false;
  }
}

