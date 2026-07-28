import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/api_response_handler.dart';
import '../../../data/models/login_response.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routes/app_routes.dart';
import '../controllers/auth_controller.dart';

class LoginController extends GetxController {
  LoginController(this._authRepository);

  final AuthRepository _authRepository;
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  final formKey = GlobalKey<FormState>();
  final mobileController = TextEditingController();
  final passwordController = TextEditingController();

  final isLoading = false.obs;
  final isPasswordHidden = true.obs;
  final isBranchLoading = false.obs;

  final branches = <Map<String, dynamic>>[].obs;
  final selectedBranchId = RxnString();

  // Role is now fixed to workshop
  final String selectedRole = 'workshop';

  AuthController get _authController => Get.find<AuthController>();
  AuthService get _authService => Get.find<AuthService>();

  @override
  void onInit() {
    super.onInit();
    ApiEndpoints.activeRole = 'workshop';
    fetchBranches();
  }

  @override
  void onClose() {
    mobileController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void togglePasswordVisibility() {
    isPasswordHidden.value = !isPasswordHidden.value;
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    // Mandatory Branch Check
    if (selectedBranchId.value == null || selectedBranchId.value!.isEmpty) {
      ApiResponseHandler.showErrorSnackbar('Please select a branch to continue');
      return;
    }

    isLoading.value = true;
    try {
      final response = await _authRepository.login(mobileNumber: mobileController.text.trim(), password: passwordController.text, branchId: selectedBranchId.value, role: selectedRole);
      await _handleLoginResponse(response);
    } catch (error) {
      ApiResponseHandler.showErrorSnackbar(error.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchBranches() async {
    isBranchLoading.value = true;
    try {
      // We use staff role to fetch list of branches if required by your API backend
      ApiEndpoints.activeRole = 'staff';

      final payload = {
        'offset': 0,
        'search': {'id': '', 'name': ''},
      };

      final response = await _apiProvider.post(ApiEndpoints.managerBranchRead, data: payload);
      final ok = ApiResponseHandler.handleResponse(response, showSuccessMessage: false);

      if (!ok) return;

      final data = response['data'] as Map<String, dynamic>?;
      final records = (data?['record'] as List?) ?? [];

      branches.assignAll(records.whereType<Map<String, dynamic>>().map((e) => {'id': e['id']?.toString() ?? '', 'name': e['name']?.toString() ?? ''}));

      // Switch back to workshop after fetching
      ApiEndpoints.activeRole = 'workshop';
    } catch (error) {
      ApiResponseHandler.showErrorSnackbar("Failed to load branches: $error");
    } finally {
      isBranchLoading.value = false;
    }
  }

  Future<void> _handleLoginResponse(LoginResponse response) async {
    final payload = response.raw ?? response.data;
    if (payload == null) {
      ApiResponseHandler.showErrorSnackbar(AppStrings.defaultError);
      return;
    }

    final handled = ApiResponseHandler.handleResponse(payload, showErrorMessage: true);
    if (!handled) return;

    if (response.isSuccess && response.data != null) {
      final token = response.data?['token']?.toString() ?? payload['data']?['token']?.toString();

      if (token == null || token.isEmpty) {
        ApiResponseHandler.showErrorSnackbar(response.message ?? AppStrings.defaultError);
        return;
      }

      await _authService.saveTokens(token);

      final Map<String, dynamic> sessionData = {...response.data!, 'token': token, 'role': selectedRole, 'logged_in_at': DateTime.now().toIso8601String()};

      await _authController.saveSession(sessionData);
      Get.offAllNamed(Routes.repairs);
    } else {
      ApiResponseHandler.showErrorSnackbar(response.message ?? AppStrings.loginInvalidCredentials);
    }
  }
}
