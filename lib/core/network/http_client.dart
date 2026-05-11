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

    Future<http.Response> sendMultipart(String? overrideToken) async {
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

      _logApiRequest(
        'POST',
        uri,
        body: <String, dynamic>{
          'fields': fields ?? <String, String>{},
          'files': filePaths ?? <String, String>{},
        },
      );
      final http.StreamedResponse streamedResponse;
      try {
        streamedResponse = await _client.send(request);
      } catch (error) {
        _logApiError('POST', uri, error);
        rethrow;
      }
      final responseBody = await streamedResponse.stream.bytesToString();
      final response = http.Response(
        responseBody,
        streamedResponse.statusCode,
        headers: streamedResponse.headers,
        request: http.Request('POST', uri),
      );
      _logApiResponse(response);
      return response;
    }

    final initialResponse = await sendMultipart(null);
    final probeRequest = http.Request('POST', uri);
    if (_shouldRefresh(initialResponse, probeRequest)) {
      try {
        final newToken = await _authService?.refreshToken();
        if (newToken != null && newToken.isNotEmpty) {
          return await sendMultipart(newToken);
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
    _logApiRequest(
      request.method,
      request.url,
      body: request.body.isEmpty ? <String, dynamic>{} : request.body,
    );
    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _client.send(request);
    } catch (error) {
      _logApiError(request.method, request.url, error);
      rethrow;
    }
    final responseBody = await streamedResponse.stream.bytesToString();
    final response = http.Response(
      responseBody,
      streamedResponse.statusCode,
      headers: streamedResponse.headers,
      request: request,
    );
    _logApiResponse(response);

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
      debugPrint('[HttpClient] Received 401 for ${request.url.path}');
      return true;
    }
    if (response.statusCode == 400 && _isTokenExpired(response.body)) {
      debugPrint(
        '[HttpClient] 400 with token expiration message for ${request.url.path}',
      );
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
      debugPrint(
        '[HttpClient] Starting token refresh after ${originalRequest.url.path}',
      );
      try {
        final newToken = await _authService?.refreshToken();
        _isRefreshing = false;

        if (newToken != null && newToken.isNotEmpty) {
          debugPrint(
            '[HttpClient] Token refresh succeeded, retrying queued requests',
          );
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
      debugPrint(
        '[HttpClient] Refresh already in progress, queueing ${originalRequest.url.path}',
      );
      final completer = Completer<http.Response>();
      _pendingRequests.add(_PendingRequest(originalRequest, completer));
      return completer.future;
    }
  }

  Future<void> _retryPendingRequests(String token) async {
    for (final pending in _pendingRequests) {
      final request = _cloneRequest(pending.request, token);
      try {
        _logApiRequest(
          request.method,
          request.url,
          body: request.body.isEmpty ? <String, dynamic>{} : request.body,
        );
        final response = await _client.send(request);
        final body = await response.stream.bytesToString();
        final completedResponse = http.Response(
          body,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
        _logApiResponse(completedResponse);
        pending.completer.complete(completedResponse);
      } catch (error) {
        _logApiError(request.method, request.url, error);
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
    _logApiRequest(
      newRequest.method,
      newRequest.url,
      body: newRequest.body.isEmpty ? <String, dynamic>{} : newRequest.body,
    );
    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _client.send(newRequest);
    } catch (error) {
      _logApiError(newRequest.method, newRequest.url, error);
      rethrow;
    }
    final responseBody = await streamedResponse.stream.bytesToString();
    final response = http.Response(
      responseBody,
      streamedResponse.statusCode,
      headers: streamedResponse.headers,
      request: newRequest,
    );
    _logApiResponse(response);

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
    debugPrint('[HttpClient] Logging out user due to invalid token');
    if (Get.isRegistered<AuthController>()) {
      await Get.find<AuthController>().clearSession();
    } else {
      await _authService?.clearTokens();
    }
  }

  void _logApiRequest(String method, Uri uri, {Object? body}) {
    debugPrint('========== API REQUEST ==========');
    debugPrint('$method $uri');
    debugPrint('Body: ${_formatJsonForLog(body ?? <String, dynamic>{})}');
  }

  void _logApiResponse(http.Response response) {
    debugPrint('========== API RESPONSE ==========');
    debugPrint(
      '${response.request?.method ?? 'HTTP'} ${response.request?.url ?? ''} [${response.statusCode}]',
    );
    debugPrint('Body: ${_formatJsonForLog(response.body)}');
  }

  void _logApiError(String method, Uri uri, Object error) {
    debugPrint('========== API RESPONSE ==========');
    debugPrint('$method $uri [ERROR]');
    debugPrint('Body: ${_formatJsonForLog({'error': error.toString()})}');
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

class _PendingRequest {
  _PendingRequest(this.request, this.completer);

  final http.Request request;
  final Completer<http.Response> completer;
}
