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
    final token = savedUser?['token']?.toString();
    if (savedUser == null || token == null || token.isEmpty) {
      await clearSession();
      return false;
    }

    // Restore the persisted session before the first authenticated route opens.
    await _authService.saveTokens(token);
    final currentToken = await _authService.getValidAccessToken();
    if (currentToken != null && currentToken != token) {
      savedUser['token'] = currentToken;
      await _storageService.saveUser(savedUser);
    }
    user.value = savedUser;
    isLoggedIn.value = true;
    return true;
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
