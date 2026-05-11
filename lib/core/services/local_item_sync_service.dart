import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../constants/api_endpoints.dart';
import '../../data/models/order_models.dart';

class LocalItemSyncService extends GetxService {
  final http.Client _client = http.Client();
  static const Duration _serverTimeout = Duration(seconds: 5);

  Future<List<PriceCategoryModel>> fetchPriceCategories() async {
    final outcomes = await Future.wait(
      _servers.map(
        (server) => _fetchJsonOutcome(
          serverName: server.name,
          baseUrl: server.baseUrl,
          endpointPath: '/api/price-categories',
        ),
      ),
    );

    final merged = <int, PriceCategoryModel>{};
    for (final outcome in outcomes) {
      final response = outcome.response;
      if (response == null) {
        continue;
      }
      final raw = response['data'];
      if (raw is! List) {
        continue;
      }

      for (final item in raw.whereType<Map>()) {
        final category = PriceCategoryModel.fromJson(
          Map<String, dynamic>.from(item),
        );
        merged.putIfAbsent(category.categoryNo, () => category);
      }
    }

    final categories = merged.values.toList()
      ..sort((a, b) => a.categoryNo.compareTo(b.categoryNo));
    return categories;
  }

  Future<MergedItemDetailModel> fetchItemDetailByLookup(String lookup) async {
    final lookupCandidates = _buildLookupCandidates(lookup);
    if (lookupCandidates.isEmpty) {
      throw Exception('Enter a QR code or item code.');
    }

    var anyReachableServer = false;
    var lastOutcomes = const <_FetchOutcome>[];

    for (final candidate in lookupCandidates) {
      final outcomes = await Future.wait(
        _servers.map(
          (server) => _fetchJsonOutcome(
            serverName: server.name,
            baseUrl: server.baseUrl,
            endpointPath: '/api/items/detail/${Uri.encodeComponent(candidate)}',
          ),
        ),
      );
      lastOutcomes = outcomes;
      anyReachableServer =
          anyReachableServer || outcomes.any((outcome) => outcome.isReachable);

      final successful = outcomes
          .where((outcome) => outcome.response != null)
          .toList();
      if (successful.isEmpty) {
        continue;
      }

      final warnings = <String>[
        for (final outcome in outcomes)
          if (!outcome.isReachable)
            '${outcome.serverName} server is unavailable right now.',
      ];

      MergedItemDetailModel? mergedDetail;
      for (final outcome in successful) {
        final response = outcome.response!;
        final rawData = response['data'];
        if (rawData is! Map) {
          continue;
        }

        final detail = _buildItemDetailFromServer(
          Map<String, dynamic>.from(rawData),
          serverName: outcome.serverName,
          baseUrl: outcome.baseUrl,
        );

        mergedDetail = mergedDetail == null
            ? detail
            : _mergeItemDetails(mergedDetail, detail);
      }

      if (mergedDetail == null) {
        continue;
      }

      return MergedItemDetailModel(
        itemMasterCode: mergedDetail.itemMasterCode,
        itemCode: mergedDetail.itemCode,
        itemName: mergedDetail.itemName,
        itemGroup: mergedDetail.itemGroup,
        qrCode: mergedDetail.qrCode,
        hsnCode: mergedDetail.hsnCode,
        totalQuantity: mergedDetail.totalQuantity,
        totalQuantityValue: mergedDetail.totalQuantityValue,
        serverQuantities: mergedDetail.serverQuantities,
        serverBranchStocks: mergedDetail.serverBranchStocks,
        image: mergedDetail.image,
        imageUrls: mergedDetail.imageUrls,
        prices: mergedDetail.prices,
        supportItemCodes: mergedDetail.supportItemCodes,
        warnings: warnings,
      );
    }

    if (!anyReachableServer) {
      final reachableCount = lastOutcomes
          .where((outcome) => outcome.isReachable)
          .length;
      if (reachableCount == 0) {
        throw Exception(
          'Item servers are unavailable right now. Check the dashboard status.',
        );
      }
    }

    throw Exception('No item matched this QR code.');
  }

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
    return _fetchJsonFromServer(
      baseUrl: baseUrl,
      endpointPath: '/api/items',
      queryParameters: queryParameters,
    );
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

  Future<Map<String, dynamic>> _fetchJsonFromServer({
    required String baseUrl,
    required String endpointPath,
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$endpointPath',
    ).replace(queryParameters: queryParameters);

    _logApiRequest('GET', uri, body: <String, dynamic>{});
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_serverTimeout);
    } catch (error) {
      _logApiError('GET', uri, error);
      rethrow;
    }
    _logApiResponse(uri, response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _HttpStatusException(response.statusCode);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Invalid item response');
  }

  void _logApiRequest(String method, Uri uri, {Object? body}) {
    debugPrint('========== LOCAL API REQUEST ==========');
    debugPrint('$method $uri');
    debugPrint('Body: ${_formatJsonForLog(body ?? <String, dynamic>{})}');
  }

  void _logApiResponse(Uri uri, http.Response response) {
    debugPrint('========== LOCAL API RESPONSE ==========');
    debugPrint('GET $uri [${response.statusCode}]');
    debugPrint('Body: ${_formatJsonForLog(response.body)}');
  }

  void _logApiError(String method, Uri uri, Object error) {
    debugPrint('========== LOCAL API RESPONSE ==========');
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

  Future<_FetchOutcome> _fetchJsonOutcome({
    required String serverName,
    required String baseUrl,
    required String endpointPath,
    Map<String, String>? queryParameters,
  }) async {
    try {
      final response = await _fetchJsonFromServer(
        baseUrl: baseUrl,
        endpointPath: endpointPath,
        queryParameters: queryParameters,
      );
      return _FetchOutcome(
        serverName: serverName,
        baseUrl: baseUrl,
        response: response,
        isReachable: true,
      );
    } on TimeoutException {
      return _FetchOutcome(
        serverName: serverName,
        baseUrl: baseUrl,
        isTimeout: true,
      );
    } on _HttpStatusException catch (error) {
      return _FetchOutcome(
        serverName: serverName,
        baseUrl: baseUrl,
        statusCode: error.statusCode,
        isReachable: true,
      );
    } catch (error) {
      return _FetchOutcome(
        serverName: serverName,
        baseUrl: baseUrl,
        errorMessage: error.toString(),
      );
    }
  }

  MergedItemDetailModel _buildItemDetailFromServer(
    Map<String, dynamic> json, {
    required String serverName,
    required String baseUrl,
  }) {
    final imageJson = json['image'];
    final pricesJson = json['prices'];
    final image = imageJson is Map
        ? ItemImageModel.fromJson(
            Map<String, dynamic>.from(imageJson),
            baseUrl: baseUrl,
          )
        : null;
    final imageUrls = <String>[
      if ((image?.available ?? false) && (image?.url?.isNotEmpty ?? false))
        image!.url!,
    ];

    return MergedItemDetailModel(
      itemMasterCode: _parseInt(
        json['itemMasterCode'] ?? json['item_master_code'],
      ),
      itemCode: (json['itemCode'] ?? json['item_code'] ?? '').toString(),
      itemName: (json['itemName'] ?? json['item_name'] ?? '').toString(),
      itemGroup: (json['itemGroup'] ?? json['item_group'] ?? '').toString(),
      qrCode: _parseNullableString(json['qrCode'] ?? json['qr_code']),
      hsnCode: _parseNullableString(json['hsnCode'] ?? json['hsn_code']),
      totalQuantity: _parseDouble(
        json['itemQuantity'] ?? json['quantity'] ?? json['qty'],
      ),
      totalQuantityValue: _parseDouble(
        json['itemQuantityValue'] ?? json['item_quantity_value'],
      ),
      serverQuantities: <String, double>{
        serverName: _parseDouble(
          json['itemQuantity'] ?? json['quantity'] ?? json['qty'],
        ),
      },
      serverBranchStocks: <String, List<BranchStockModel>>{
        serverName: json['branchStocks'] is List
            ? (json['branchStocks'] as List)
                  .whereType<Map>()
                  .map(
                    (item) => BranchStockModel.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .toList()
            : const <BranchStockModel>[],
      },
      image: image,
      imageUrls: imageUrls,
      prices: pricesJson is List
          ? pricesJson
                .whereType<Map>()
                .map(
                  (item) =>
                      ItemPriceModel.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const <ItemPriceModel>[],
      supportItemCodes: json['supportItemCodes'] is List
          ? (json['supportItemCodes'] as List)
                .map((value) => value.toString())
                .where((value) => value.trim().isNotEmpty)
                .toList()
          : const <String>[],
      warnings: const <String>[],
    );
  }

  MergedItemDetailModel _mergeItemDetails(
    MergedItemDetailModel primary,
    MergedItemDetailModel secondary,
  ) {
    final mergedQuantities = <String, double>{...primary.serverQuantities};
    secondary.serverQuantities.forEach((server, quantity) {
      mergedQuantities[server] = (mergedQuantities[server] ?? 0) + quantity;
    });
    final mergedBranchStocks = <String, List<BranchStockModel>>{
      ...primary.serverBranchStocks,
      ...secondary.serverBranchStocks,
    };

    final mergedPrices = <String, ItemPriceModel>{};
    for (final price in [...primary.prices, ...secondary.prices]) {
      final key = '${price.categoryNo}|${price.slotId}|${price.categoryCode}';
      mergedPrices.putIfAbsent(key, () => price);
    }

    final mergedSupportCodes = <String>{
      ...primary.supportItemCodes,
      ...secondary.supportItemCodes,
    }.toList();

    final imageUrls = <String>{
      ...primary.imageUrls,
      ...secondary.imageUrls,
    }.where((url) => url.trim().isNotEmpty).toList();

    final image = (primary.image?.available ?? false)
        ? primary.image
        : secondary.image;

    return MergedItemDetailModel(
      itemMasterCode: primary.itemMasterCode ?? secondary.itemMasterCode,
      itemCode: primary.itemCode.isNotEmpty
          ? primary.itemCode
          : secondary.itemCode,
      itemName: primary.itemName.isNotEmpty
          ? primary.itemName
          : secondary.itemName,
      itemGroup: primary.itemGroup.isNotEmpty
          ? primary.itemGroup
          : secondary.itemGroup,
      qrCode: primary.qrCode ?? secondary.qrCode,
      hsnCode: primary.hsnCode ?? secondary.hsnCode,
      totalQuantity: primary.totalQuantity + secondary.totalQuantity,
      totalQuantityValue:
          primary.totalQuantityValue + secondary.totalQuantityValue,
      serverQuantities: mergedQuantities,
      serverBranchStocks: mergedBranchStocks,
      image: image,
      imageUrls: imageUrls,
      prices: mergedPrices.values.toList()
        ..sort((a, b) => a.categoryNo.compareTo(b.categoryNo)),
      supportItemCodes: mergedSupportCodes,
      warnings: <String>[...primary.warnings, ...secondary.warnings],
    );
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

  List<String> _buildLookupCandidates(String lookup) {
    final candidates = <String>[];

    void addCandidate(String? value) {
      final normalized = value?.trim() ?? '';
      if (normalized.isEmpty || candidates.contains(normalized)) {
        return;
      }
      candidates.add(normalized);
    }

    final trimmed = lookup.trim();
    addCandidate(trimmed);
    addCandidate(trimmed.replaceAll(RegExp(r'\s+'), ''));

    final possibleUri = Uri.tryParse(trimmed);
    if (possibleUri != null) {
      addCandidate(possibleUri.queryParameters['code']);
      addCandidate(possibleUri.queryParameters['itemCode']);
      addCandidate(possibleUri.queryParameters['item_code']);
      addCandidate(possibleUri.queryParameters['qr']);
      addCandidate(possibleUri.queryParameters['qrCode']);
      addCandidate(possibleUri.queryParameters['qrcode']);
      if (possibleUri.pathSegments.isNotEmpty) {
        addCandidate(possibleUri.pathSegments.last);
      }
    }

    if (trimmed.contains('/')) {
      addCandidate(trimmed.split('/').last);
    }
    if (trimmed.contains('\\')) {
      addCandidate(trimmed.split('\\').last);
    }
    if (trimmed.contains(':')) {
      addCandidate(trimmed.split(':').last);
    }
    if (trimmed.contains('=')) {
      addCandidate(trimmed.split('=').last);
    }

    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length >= 3) {
      addCandidate(digitsOnly);
    }

    final alphaNumeric = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (alphaNumeric.length >= 3) {
      addCandidate(alphaNumeric);
    }

    return candidates;
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
    this.serverName = '',
    this.baseUrl = '',
    this.response,
    this.statusCode,
    this.isReachable = false,
    this.isTimeout = false,
    this.errorMessage,
  });

  final String serverName;
  final String baseUrl;
  final Map<String, dynamic>? response;
  final int? statusCode;
  final bool isReachable;
  final bool isTimeout;
  final String? errorMessage;
}

class _HttpStatusException implements Exception {
  const _HttpStatusException(this.statusCode);

  final int statusCode;
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}

double _parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '') ?? 0;
}

String? _parseNullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
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
