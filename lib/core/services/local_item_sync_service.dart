import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../constants/api_endpoints.dart';
import '../../data/models/order_models.dart';

class LocalItemSyncService extends GetxService {
  final http.Client _client = http.Client();
  static const Duration _serverTimeout = Duration(seconds: 5);

  Future<MergedItemPage> searchItems({
    required int page,
    required int pageSize,
    required String query,
  }) async {
    final merged = <String, MergedItemModel>{};
    final serverResults = await Future.wait(
      _servers.map(
        (server) => _searchServer(
          server: server,
          page: page,
          pageSize: pageSize,
          query: query,
        ),
      ),
    );

    final reachableServerCount = serverResults
        .where((result) => result.isReachable)
        .length;
    final warnings = <String>[
      if (reachableServerCount == 0)
        'Item servers are unavailable right now. Check the dashboard status.',
    ];

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

    return filterLoadedItems(
      items: merged.values,
      page: page,
      pageSize: pageSize,
      query: '',
      warnings: warnings,
      forceHasMore: serverResults.any((result) => result.hasMore),
    );
  }

  MergedItemPage filterLoadedItems({
    required Iterable<MergedItemModel> items,
    required int page,
    required int pageSize,
    required String query,
    List<String> warnings = const <String>[],
    bool forceHasMore = false,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final filtered =
        items.where((item) {
          if (normalizedQuery.isEmpty) {
            return true;
          }

          final itemCode = item.itemCode.trim().toLowerCase();
          final itemName = item.itemName.trim().toLowerCase();
          final qrCode = item.qrCode?.trim().toLowerCase() ?? '';
          return itemCode.contains(normalizedQuery) ||
              itemName.contains(normalizedQuery) ||
              qrCode.contains(normalizedQuery);
        }).toList()..sort((a, b) {
          final codeCompare = a.itemCode.compareTo(b.itemCode);
          if (codeCompare != 0) return codeCompare;
          return a.itemName.compareTo(b.itemName);
        });

    final start = (math.max(page, 1) - 1) * pageSize;
    final end = math.min(start + pageSize, filtered.length);
    final hasMore = end < filtered.length || forceHasMore;

    return MergedItemPage(
      items: start < filtered.length
          ? filtered.sublist(start, end)
          : <MergedItemModel>[],
      hasMore: hasMore,
      warnings: warnings,
    );
  }

  Future<Map<String, dynamic>> _fetchItemsFromServer({
    required String baseUrl,
    required Map<String, String> queryParameters,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/items',
    ).replace(queryParameters: queryParameters);

    final response = await _client.get(uri).timeout(_serverTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Invalid item response');
  }

  Future<_ServerItemBatch> _searchServer({
    required _LocalServerConfig server,
    required int page,
    required int pageSize,
    required String query,
  }) async {
    final items = <Map<String, dynamic>>[];
    var hasMore = false;
    var isReachable = false;

    for (var currentPage = 1; currentPage <= page; currentPage++) {
      final requests = _buildServerQueryParameters(
        page: currentPage,
        pageSize: pageSize,
        query: query,
      );
      final outcomes = await Future.wait(
        requests.map(
          (queryParameters) => _fetchItemsOutcome(
            baseUrl: server.baseUrl,
            queryParameters: queryParameters,
          ),
        ),
      );

      final successfulOutcomes = outcomes
          .where((outcome) => outcome.response != null)
          .toList();

      if (successfulOutcomes.isEmpty) {
        break;
      }

      isReachable = true;
      final pageItems = <String, Map<String, dynamic>>{};
      hasMore = false;

      for (final outcome in successfulOutcomes) {
        final response = outcome.response!;
        if (response['data'] is! List) {
          continue;
        }

        final batch = (response['data'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        for (final item in batch) {
          pageItems[_buildServerItemKey(item)] = item;
        }

        hasMore = hasMore || _responseHasMore(response, currentPage, pageSize);
      }

      items.addAll(pageItems.values);

      if (!hasMore) {
        break;
      }
    }

    return _ServerItemBatch(
      serverName: server.name,
      items: items,
      hasMore: hasMore,
      isReachable: isReachable,
    );
  }

  Future<_FetchOutcome> _fetchItemsOutcome({
    required String baseUrl,
    required Map<String, String> queryParameters,
  }) async {
    try {
      final response = await _fetchItemsFromServer(
        baseUrl: baseUrl,
        queryParameters: queryParameters,
      );
      return _FetchOutcome(response: response);
    } on TimeoutException {
      return const _FetchOutcome(isTimeout: true);
    } catch (error) {
      return _FetchOutcome(errorMessage: error.toString());
    }
  }

  List<Map<String, String>> _buildServerQueryParameters({
    required int page,
    required int pageSize,
    required String query,
  }) {
    final trimmedQuery = query.trim();
    final base = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };

    if (trimmedQuery.isEmpty) {
      return <Map<String, String>>[base];
    }

    return <Map<String, String>>[
      <String, String>{...base, 'itemCode': trimmedQuery},
      <String, String>{...base, 'itemName': trimmedQuery},
    ];
  }

  bool _responseHasMore(
    Map<String, dynamic> response,
    int currentPage,
    int pageSize,
  ) {
    final pagination = response['pagination'];
    final totalPages = pagination is Map
        ? int.tryParse(pagination['totalPages']?.toString() ?? '')
        : null;

    if (totalPages != null) {
      return currentPage < totalPages;
    }

    final data = response['data'];
    return data is List && data.length >= pageSize;
  }

  String _buildServerItemKey(Map<String, dynamic> item) {
    final masterCode = item['itemMasterCode']?.toString().trim() ?? '';
    if (masterCode.isNotEmpty) {
      return masterCode;
    }

    final itemCode = item['itemCode']?.toString().trim() ?? '';
    final itemName = item['itemName']?.toString().trim() ?? '';
    final qrCode = item['qrCode']?.toString().trim() ?? '';
    return '$itemCode|$itemName|$qrCode';
  }
}

class _LocalServerConfig {
  const _LocalServerConfig({required this.name, required this.baseUrl});

  final String name;
  final String baseUrl;
}

class _ServerItemBatch {
  const _ServerItemBatch({
    required this.serverName,
    required this.items,
    required this.hasMore,
    required this.isReachable,
  });

  final String serverName;
  final List<Map<String, dynamic>> items;
  final bool hasMore;
  final bool isReachable;
}

class _FetchOutcome {
  const _FetchOutcome({
    this.response,
    this.isTimeout = false,
    this.errorMessage,
  });

  final Map<String, dynamic>? response;
  final bool isTimeout;
  final String? errorMessage;
}

const List<_LocalServerConfig> _servers = <_LocalServerConfig>[
  _LocalServerConfig(
    name: ApiEndpoints.ahmLabel,
    baseUrl: ApiEndpoints.ahmItemsBaseUrl,
  ),
  _LocalServerConfig(
    name: ApiEndpoints.bhuLabel,
    baseUrl: ApiEndpoints.bhuItemsBaseUrl,
  ),
];
