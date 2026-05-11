import 'dart:convert';

import 'package:flutter/foundation.dart';
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
      debugPrint('[AuthService] refreshToken aborted: no stored token');
      return null;
    }

    final uri = Uri.parse(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.refreshToken}',
    );
    _logApiRequest('GET', uri, body: <String, dynamic>{});
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
      _logApiResponse('GET', uri, response.statusCode, response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[AuthService] Refresh token failed with status ${response.statusCode}',
        );
        return null;
      }

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;
      final bool status =
          body['status'] == true ||
          body['success'] == true ||
          (body['code']?.toString() == '200');
      if (!status) {
        return null;
      }

      final Map<String, dynamic>? data = body['data'] is Map<String, dynamic>
          ? body['data']
          : null;
      final String? newToken =
          data?['token']?.toString() ?? body['token']?.toString();
      if (newToken == null || newToken.isEmpty) {
        debugPrint('[AuthService] Refresh token response missing token');
        return null;
      }

      await saveTokens(newToken);
      debugPrint('[AuthService] Refresh token succeeded and token saved');
      return newToken;
    } catch (error, stackTrace) {
      _logApiResponse('GET', uri, -1, {'error': error.toString()});
      debugPrint('[AuthService] Refresh token error: $error\n$stackTrace');
      return null;
    }
  }

  void _logApiRequest(String method, Uri uri, {Object? body}) {
    debugPrint('========== AUTH API REQUEST ==========');
    debugPrint('$method $uri');
    debugPrint('Body: ${_formatJsonForLog(body ?? <String, dynamic>{})}');
  }

  void _logApiResponse(String method, Uri uri, int statusCode, Object? body) {
    debugPrint('========== AUTH API RESPONSE ==========');
    debugPrint('$method $uri [$statusCode]');
    debugPrint('Body: ${_formatJsonForLog(body)}');
  }

  String _formatJsonForLog(Object? value) {
    try {
      final dynamic jsonValue;
      if (value == null) {
        jsonValue = <String, dynamic>{};
      } else if (value is String) {
        jsonValue = value.trim().isEmpty
            ? <String, dynamic>{}
            : jsonDecode(value);
      } else {
        jsonValue = value;
      }
      return const JsonEncoder.withIndent('  ').convert(jsonValue);
    } catch (_) {
      return value?.toString() ?? '';
    }
  }
}
