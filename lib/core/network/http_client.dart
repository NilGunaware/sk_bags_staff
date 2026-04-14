import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../constants/api_endpoints.dart';
import '../services/auth_service.dart';
import '../../modules/auth/controllers/auth_controller.dart';

class HttpClient {
  HttpClient._();

  static HttpClient? _instance;
  static AuthService? _authService;

  final http.Client _client = http.Client();
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  static HttpClient getInstance() {
    _instance ??= HttpClient._();
    _authService ??= Get.find<AuthService>();
    return _instance!;
  }

  static void reset() {
    _instance?._client.close();
    _instance = null;
  }

  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
  }) async {
    var uri = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(
        queryParameters: queryParams.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        ),
      );
    }

    final request = http.Request('GET', uri);
    request.headers.addAll(await _getHeaders(additionalHeaders: headers));
    return _sendWithRefresh(request);
  }

  Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Object? body,
  }) async {
    var uri = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(
        queryParameters: queryParams.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        ),
      );
    }
    final request = http.Request('POST', uri);
    request.headers.addAll(await _getHeaders(additionalHeaders: headers));
    _attachBody(request, body);
    return _sendWithRefresh(request);
  }

  Future<http.Response> put(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Object? body,
  }) async {
    var uri = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(
        queryParameters: queryParams.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        ),
      );
    }
    final request = http.Request('PUT', uri);
    request.headers.addAll(await _getHeaders(additionalHeaders: headers));
    _attachBody(request, body);
    return _sendWithRefresh(request);
  }

  Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Object? body,
  }) async {
    var uri = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(
        queryParameters: queryParams.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        ),
      );
    }
    final request = http.Request('DELETE', uri);
    request.headers.addAll(await _getHeaders(additionalHeaders: headers));
    _attachBody(request, body);
    return _sendWithRefresh(request);
  }

  Future<http.Response> postMultipartFromPaths(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Map<String, String>? fields,
    Map<String, String>? filePaths,
  }) async {
    var uri = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(
        queryParameters: queryParams.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        ),
      );
    }

    Future<http.Response> _sendMultipart(String? overrideToken) async {
      final request = http.MultipartRequest('POST', uri);
      final hdrs = await _getHeaders(additionalHeaders: headers);
      hdrs.remove('Content-Type');
      if (overrideToken != null && overrideToken.isNotEmpty) {
        hdrs['Auth'] = 'Bearer $overrideToken';
      }
      request.headers.addAll(hdrs);

      if (fields != null && fields.isNotEmpty) {
        request.fields.addAll(fields);
      }
      if (filePaths != null && filePaths.isNotEmpty) {
        for (final entry in filePaths.entries) {
          request.files.add(
            await http.MultipartFile.fromPath(entry.key, entry.value),
          );
        }
      }

      final streamedResponse = await _client.send(request);
      final responseBody = await streamedResponse.stream.bytesToString();
      return http.Response(
        responseBody,
        streamedResponse.statusCode,
        headers: streamedResponse.headers,
        request: http.Request('POST', uri),
      );
    }

    final initialResponse = await _sendMultipart(null);
    final probeRequest = http.Request('POST', uri);
    if (_shouldRefresh(initialResponse, probeRequest)) {
      try {
        final newToken = await _authService?.refreshToken();
        if (newToken != null && newToken.isNotEmpty) {
          return await _sendMultipart(newToken);
        } else {
          await _logoutUser();
          return initialResponse;
        }
      } catch (_) {
        await _logoutUser();
        return initialResponse;
      }
    }
    return initialResponse;
  }

  Future<http.Response> _sendWithRefresh(http.Request request) async {
    final streamedResponse = await _client.send(request);
    final responseBody = await streamedResponse.stream.bytesToString();
    final response = http.Response(
      responseBody,
      streamedResponse.statusCode,
      headers: streamedResponse.headers,
      request: request,
    );

    if (_shouldRefresh(response, request)) {
      return _handle401Error(request, response);
    }

    return response;
  }

  bool _shouldRefresh(http.Response response, http.Request request) {
    if (request.url.path.contains(ApiEndpoints.refreshToken)) {
      return false;
    }
    if (response.statusCode == 401) {
      print('[HttpClient] Received 401 for ${request.url.path}');
      return true;
    }
    if (response.statusCode == 400 && _isTokenExpired(response.body)) {
      print('[HttpClient] 400 with token expiration message for ${request.url.path}');
      return true;
    }
    return false;
  }

  bool _isTokenExpired(String responseBody) {
    try {
      final lower = responseBody.toLowerCase();
      return lower.contains('token time expire') ||
          lower.contains('token expired') ||
          lower.contains('token is expired') ||
          lower.contains('token has expired') ||
          lower.contains('invalid token') ||
          lower.contains('unauthorized') ||
          lower.contains('authentication failed');
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> _getHeaders({
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Api-Access-Key': ApiEndpoints.apiAccessKey,
    };

    final token = await _authService?.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Auth'] = 'Bearer $token';
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    return headers;
  }

  void _attachBody(http.Request request, Object? body) {
    if (body == null) return;
    if (body is Map || body is List) {
      request.body = jsonEncode(body);
    } else if (body is String) {
      request.body = body;
    } else {
      request.body = body.toString();
    }
  }

  Future<http.Response> _handle401Error(
    http.Request originalRequest,
    http.Response errorResponse,
  ) async {
    final path = originalRequest.url.path;

    if (path.contains(ApiEndpoints.refreshToken)) {
      await _logoutUser();
      return errorResponse;
    }

    if (!_isRefreshing) {
      _isRefreshing = true;
      print('[HttpClient] Starting token refresh after ${originalRequest.url.path}');
      try {
        final newToken = await _authService?.refreshToken();
        _isRefreshing = false;

        if (newToken != null && newToken.isNotEmpty) {
          print('[HttpClient] Token refresh succeeded, retrying queued requests');
          await _retryPendingRequests(newToken);
          return _retryRequest(originalRequest, newToken);
        } else {
          await _failPendingRequests();
          await _logoutUser();
          return errorResponse;
        }
      } catch (error, stackTrace) {
        debugPrint('Token refresh error: $error\n$stackTrace');
        _isRefreshing = false;
        await _failPendingRequests();
        await _logoutUser();
        return errorResponse;
      }
    } else {
      print('[HttpClient] Refresh already in progress, queueing ${originalRequest.url.path}');
      final completer = Completer<http.Response>();
      _pendingRequests.add(_PendingRequest(originalRequest, completer));
      return completer.future;
    }
  }

  Future<void> _retryPendingRequests(String token) async {
    for (final pending in _pendingRequests) {
      try {
        final request = _cloneRequest(pending.request, token);
        final response = await _client.send(request);
        final body = await response.stream.bytesToString();
        pending.completer.complete(http.Response(
          body,
          response.statusCode,
          headers: response.headers,
          request: request,
        ));
      } catch (error) {
        pending.completer.completeError(error);
      }
    }
    _pendingRequests.clear();
  }

  Future<void> _failPendingRequests() async {
    for (final pending in _pendingRequests) {
      pending.completer.completeError(
        Exception('Session expired. Please login again.'),
      );
    }
    _pendingRequests.clear();
  }

  Future<http.Response> _retryRequest(
    http.Request originalRequest,
    String token,
  ) async {
    final newRequest = _cloneRequest(originalRequest, token);
    final streamedResponse = await _client.send(newRequest);
    final responseBody = await streamedResponse.stream.bytesToString();
    final response = http.Response(
      responseBody,
      streamedResponse.statusCode,
      headers: streamedResponse.headers,
      request: newRequest,
    );

    if (response.statusCode == 401 ||
        (response.statusCode == 400 && _isTokenExpired(response.body))) {
      await _logoutUser();
    }

    return response;
  }

  http.Request _cloneRequest(http.Request original, String token) {
    final cloned = http.Request(original.method, original.url);
    cloned.headers.addAll(original.headers);
    cloned.headers['Auth'] = 'Bearer $token';
    if (original.bodyBytes.isNotEmpty) {
      cloned.bodyBytes = original.bodyBytes;
    }
    cloned.encoding = original.encoding;
    return cloned;
  }

  Future<void> _logoutUser() async {
    print('[HttpClient] Logging out user due to invalid token');
    if (Get.isRegistered<AuthController>()) {
      await Get.find<AuthController>().clearSession();
    } else {
      await _authService?.clearTokens();
    }
  }
}

class _PendingRequest {
  _PendingRequest(this.request, this.completer);

  final http.Request request;
  final Completer<http.Response> completer;
}


