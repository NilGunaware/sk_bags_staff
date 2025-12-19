import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/network/http_client.dart';

class ApiProvider {
  ApiProvider() : _httpClient = HttpClient.getInstance();

  final HttpClient _httpClient;

  Future<Map<String, dynamic>> get(
    String path, {
      Map<String, dynamic>? queryParameters,
      String? bearerToken, // ignored: token handled by HttpClient
    }) async {
    final response = await _httpClient.get(
      path,
      queryParams: queryParameters,
    );
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
      Map<String, dynamic>? data,
      Map<String, dynamic>? queryParameters,
      String? bearerToken, // ignored: token handled by HttpClient
    }) async {
    final response = await _httpClient.post(
      path,
      queryParams: queryParameters,
      body: data,
    );
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> postMultipartFromPaths(
    String path, {
      Map<String, dynamic>? queryParameters,
      Map<String, String>? fields,
      Map<String, String>? filePaths,
    }) async {
    final response = await _httpClient.postMultipartFromPaths(
      path,
      queryParams: queryParameters,
      fields: fields,
      filePaths: filePaths,
    );
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
      Map<String, dynamic>? data,
      Map<String, dynamic>? queryParameters,
    }) async {
    final response = await _httpClient.delete(
      path,
      queryParams: queryParameters,
      body: data,
    );
    return _processResponse(response);
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    if (response.statusCode >= 400) {
      final message = _extractMessage(response.body);

      final errorMsg = message.isNotEmpty 
          ? message 
          : 'Request failed (${response.statusCode})';
          //Print('API Error: ${response.statusCode} - ${response.body}');
      throw Exception(errorMsg);
    }

    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{};
    } catch (_) {
      throw Exception('Invalid response received from server.');
    }
  }

  String _extractMessage(String body) {
    if (body.isEmpty) return '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return (decoded['message'] ??
                decoded['msg'] ??
                decoded['error'] ??
                decoded['response_message'] ??
                '')
            .toString();
      }
      return body;
    } catch (_) {
      return body;
    }
  }
}

