import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../constants/api_endpoints.dart';
import 'storage_service.dart';
import 'token_storage.dart';

class AuthService extends GetxService {
  late final StorageService _storageService;

  @override
  void onInit() {
    super.onInit();
    _storageService = Get.find<StorageService>();
  }

  Future<String?> getAccessToken() => TokenStorage.readToken();

  Future<void> saveTokens(String accessToken) async {
    await TokenStorage.saveToken(accessToken);
    final currentUser = _storageService.readUser();
    if (currentUser != null) {
      currentUser['token'] = accessToken;
      await _storageService.saveUser(currentUser);
    }
  }

  Future<void> clearTokens() async {
    await TokenStorage.clearToken();
  }

  Future<String?> refreshToken() async {
    final existingToken = await getAccessToken();
    if (existingToken == null || existingToken.isEmpty) {
      print('[AuthService] refreshToken aborted: no stored token');
      return null;
    }

    final uri =
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.refreshToken}');
    print('[AuthService] Calling refresh token API: ${uri.toString()}');
    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Api-Access-Key': ApiEndpoints.apiAccessKey,
          'Auth': 'Bearer $existingToken',
        },
      );

      print(
        '[AuthService] Refresh response [${response.statusCode}]: ${response.body}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        print(
            '[AuthService] Refresh token failed with status ${response.statusCode}');
        return null;
      }

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;
      final bool status = body['status'] == true ||
          body['success'] == true ||
          (body['code']?.toString() == '200');
      if (!status) {
        return null;
      }

      final Map<String, dynamic>? data =
          body['data'] is Map<String, dynamic> ? body['data'] : null;
      final String? newToken =
          data?['token']?.toString() ?? body['token']?.toString();
      if (newToken == null || newToken.isEmpty) {
        print('[AuthService] Refresh token response missing token');
        return null;
      }

      await saveTokens(newToken);
      print('[AuthService] Refresh token succeeded and token saved');
      return newToken;
    } catch (error, stackTrace) {
      print('[AuthService] Refresh token error: $error');
      print(stackTrace);
      return null;
    }
  }
}


