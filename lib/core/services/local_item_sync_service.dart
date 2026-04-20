import 'dart:convert';
import 'dart:math' as math;

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../constants/api_endpoints.dart';
import '../../data/models/order_models.dart';

class LocalItemSyncService extends GetxService {
  final http.Client _client = http.Client();

  Future<MergedItemPage> searchItems({
    required int page,
    required int pageSize,
    required String query,
  }) async {
    final merged = <String, MergedItemModel>{};
    final warnings = <String>[];
    final serverResults = <_ServerItemBatch>[];

    for (final server in _servers) {
      try {
        final items = <Map<String, dynamic>>[];
        var hasMore = false;

        for (var currentPage = 1; currentPage <= page; currentPage++) {
          final response = await _fetchItemsFromServer(
            baseUrl: server.baseUrl,
            page: currentPage,
            pageSize: pageSize,
            query: query,
          );

          if (response['data'] is! List) {
            continue;
          }

          final batch = (response['data'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          items.addAll(batch);

          final pagination = response['pagination'];
          final totalPages = pagination is Map
              ? int.tryParse(pagination['totalPages']?.toString() ?? '')
              : null;
          hasMore = totalPages != null ? currentPage < totalPages : batch.length >= pageSize;

          if (batch.length < pageSize && (totalPages == null || !hasMore)) {
            hasMore = false;
            break;
          }
        }

        serverResults.add(_ServerItemBatch(serverName: server.name, items: items, hasMore: hasMore));
      } catch (error) {
        warnings.add('${server.name}: $error');
      }
    }

    for (final result in serverResults) {
      for (final itemJson in result.items) {
        final item = MergedItemModel.fromServerJson(
          itemJson,
          serverName: result.serverName,
        );

        if (item.itemCode.trim().isEmpty && item.itemName.trim().isEmpty) {
          continue;
        }

        final existing = merged[item.key];
        merged[item.key] = existing == null ? item : existing.merge(item);
      }
    }

    final sorted = merged.values.toList()
      ..sort((a, b) {
        final codeCompare = a.itemCode.compareTo(b.itemCode);
        if (codeCompare != 0) return codeCompare;
        return a.itemName.compareTo(b.itemName);
      });

    final start = (math.max(page, 1) - 1) * pageSize;
    final end = math.min(start + pageSize, sorted.length);
    final hasMore = end < sorted.length || serverResults.any((result) => result.hasMore);

    return MergedItemPage(
      items: start < sorted.length ? sorted.sublist(start, end) : <MergedItemModel>[],
      hasMore: hasMore,
      warnings: warnings,
    );
  }

  Future<Map<String, dynamic>> _fetchItemsFromServer({
    required String baseUrl,
    required int page,
    required int pageSize,
    required String query,
  }) async {
    final uri = Uri.parse('$baseUrl/api/items').replace(
      queryParameters: <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        'itemCode': query,
        'itemName': query,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Invalid item response');
  }
}

class _LocalServerConfig {
  const _LocalServerConfig({
    required this.name,
    required this.baseUrl,
  });

  final String name;
  final String baseUrl;
}

class _ServerItemBatch {
  const _ServerItemBatch({
    required this.serverName,
    required this.items,
    required this.hasMore,
  });

  final String serverName;
  final List<Map<String, dynamic>> items;
  final bool hasMore;
}

const List<_LocalServerConfig> _servers = <_LocalServerConfig>[
  _LocalServerConfig(
    name: 'Server 1',
    baseUrl: ApiEndpoints.server1ItemsBaseUrl,
  ),
  _LocalServerConfig(
    name: 'Server 2',
    baseUrl: ApiEndpoints.server2ItemsBaseUrl,
  ),
];
