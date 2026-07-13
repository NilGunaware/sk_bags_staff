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
    final response = await _httpClient.get(path, queryParams: queryParameters);
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
    List<MapEntry<String, String>>? filePathEntries,
  }) async {
    final response = await _httpClient.postMultipartFromPaths(
      path,
      queryParams: queryParameters,
      fields: fields,
      filePaths: filePaths,
      filePathEntries: filePathEntries,
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
}
