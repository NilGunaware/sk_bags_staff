import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/api_response_handler.dart';
import '../../../data/models/login_response.dart';
import '../../../data/repositories/auth_repository.dart';
import '../controllers/auth_controller.dart';
import '../../../routes/app_routes.dart';

class LoginController extends GetxController {
  LoginController(this._authRepository);

  final AuthRepository _authRepository;
  final formKey = GlobalKey<FormState>();
  final mobileController = TextEditingController();
  final passwordController = TextEditingController();
  final isLoading = false.obs;

  AuthController get _authController => Get.find<AuthController>();
  AuthService get _authService => Get.find<AuthService>();

  @override
  void onClose() {
    mobileController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    isLoading.value = true;
    try {
      final response = await _authRepository.login(
        mobileNumber: mobileController.text.trim(),
        password: passwordController.text,
      );
      await _handleLoginResponse(response);
    } catch (error) {
      ApiResponseHandler.showErrorSnackbar(error.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _handleLoginResponse(LoginResponse response) async {
    final payload = response.raw ?? response.data;
    if (payload == null) {
      ApiResponseHandler.showErrorSnackbar(AppStrings.defaultError);
      return;
    }

    final handled = ApiResponseHandler.handleResponse(payload);
    if (!handled) return;

    if (response.isSuccess && response.data != null) {
      final token = response.data?['token']?.toString() ??
          payload['data']?['token']?.toString();
      if (token == null || token.isEmpty) {
        ApiResponseHandler.showErrorSnackbar(
          response.message ?? AppStrings.defaultError,
        );
        return;
      }

      await _authService.saveTokens(token);

      final Map<String, dynamic> sessionData = {
        ...response.data!,
        'token': token,
        'logged_in_at': DateTime.now().toIso8601String(),
      };

      await _authController.saveSession(sessionData);
      Get.offAllNamed(Routes.home);
    } else {
      ApiResponseHandler.showErrorSnackbar(
        response.message ?? AppStrings.loginInvalidCredentials,
      );
    }
  }
}

