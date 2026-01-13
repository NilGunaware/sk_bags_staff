import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/providers/api_provider.dart';
import '../../routes/app_routes.dart';
import '../auth/controllers/auth_controller.dart';

class HomeController extends GetxController {
  final AuthController authController = Get.find<AuthController>();
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, dynamic>? get user => authController.user.value;

  final isProfileLoading = false.obs;
  final isDeletingItem = false.obs;
  final profile = Rx<Map<String, dynamic>?>(null);
  final isScanning = false.obs;
  final scanResult = Rx<Map<String, dynamic>?>(null);
  final scanQrcodeController = TextEditingController();
  final scanCodeController = TextEditingController();
  final isStoring = false.obs;
  final showStoreForm = false.obs;
  final storeUuidController = TextEditingController(text: '${DateTime.now().millisecondsSinceEpoch}');
  final storeQuantityController = TextEditingController(text: '1');
  final storeNotesController = TextEditingController();

  final isLoadingStock = false.obs;
  final stockList = <Map<String, dynamic>>[].obs;
  final stockOffset = 0.obs;
  final stockTotal = 0.obs;

  bool canDeleteStockItem(Map<String, dynamic> item) {
    return item['is_delete']?.toString() == '1';
  }

  Future<void> fetchStockList({bool refresh = false}) async {
    if (refresh) {
      stockOffset.value = 0;
      stockList.clear();
      stockTotal.value = 0;
    }
    isLoadingStock.value = true;
    try {
      final payload = {
        'offset': stockOffset.value,
        'search': {
          'id': '',
          'code': '',
          'qrcode': '',
          'item_name': '',
          'group_name': '',
          'company_name': '',
          'quantity': {'from': '', 'to': ''},
        },
      };
      final response = await _apiProvider.post(ApiEndpoints.stockRead, data: payload);
      final ok = ApiResponseHandler.handleResponse(response, showSuccessMessage: false);
      if (ok) {
        final data = response['data'] is Map<String, dynamic> ? Map<String, dynamic>.from(response['data'] as Map) : <String, dynamic>{};

        stockTotal.value = int.tryParse(data['total']?.toString() ?? '0') ?? 0;
        final records = data['record'];
        if (records is List) {
          final list = records.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          stockList.addAll(list);
          stockOffset.value += list.length;
        }
      }
    } catch (error) {
      ApiResponseHandler.showErrorSnackbar(error.toString());
    } finally {
      isLoadingStock.value = false;
    }
  }

  Future<bool> deleteStockItemRecord(Map<String, dynamic> item) async {
    if (!canDeleteStockItem(item)) return false;
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return false;
    
    isDeletingItem.value = true;
    try {
      return await deleteStockItem(id);
    } finally {
      isDeletingItem.value = false;
    }
  }

  Future<void> storeItemEnsureScan() async {
    final qtyStr = storeQuantityController.text.trim();
    final qty = int.tryParse(qtyStr) ?? 0;
    if (qty <= 0) {
      ApiResponseHandler.showErrorSnackbar('Enter a valid quantity');
      return;
    }
    isStoring.value = true;
    try {
      if (scanResult.value == null || scanResult.value!.isEmpty) {
        final payload = {'qrcode': scanQrcodeController.text.trim(), 'code': scanCodeController.text.trim()};
        final response = await _apiProvider.post(ApiEndpoints.scanQrcode, data: payload);
        final ok = ApiResponseHandler.handleResponse(response, showErrorMessage: true);
        if (!ok) return;
        final data = response['data'] is Map<String, dynamic> ? Map<String, dynamic>.from(response['data'] as Map) : <String, dynamic>{};
        scanResult.value = data;
        showStoreForm.value = true;
      }
      final current = scanResult.value;
      final itemId = current?['item_id']?.toString() ?? '';
      final itemCode = current?['item_code']?.toString() ?? '';
      if (itemId.isEmpty) {
        ApiResponseHandler.showErrorSnackbar('Invalid item');
        return;
      }
      final payloadStore = {'uuid': storeUuidController.text.trim().isEmpty ? '${DateTime.now().millisecondsSinceEpoch}' : storeUuidController.text.trim(), 'item_id': itemId, 'item_code': itemCode, 'quantity': qtyStr, 'notes': storeNotesController.text.trim()};
      final responseStore = await _apiProvider.post(ApiEndpoints.stockStoreCreate, data: payloadStore);
      final okStore = ApiResponseHandler.handleResponse(responseStore, showErrorMessage: true);
      if (okStore) {
        resetScanner();
        fetchStockList(refresh: true);
      }
    } catch (_) {
    } finally {
      isStoring.value = false;
    }
  }

  Future<bool> deleteStockItem(String id) async {
    try {
      final url = '${ApiEndpoints.stockRemove}/$id';
      final response = await _apiProvider.delete(url);
      final ok = ApiResponseHandler.handleResponse(response, showErrorMessage: true, showSuccessMessage: false);
      if (ok) {
        await fetchStockList(refresh: true);
        return true;
      }
      return false;
    } catch (error) {
      ApiResponseHandler.showErrorSnackbar(error.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await authController.clearSession();
    Get.offAllNamed(Routes.login);
  }

  String _sanitizeUrl(String? url) {
    if (url == null) return '';
    return url.replaceAll('`', '').replaceAll(' ', '').replaceAll(',', '');
  }

  Future<void> fetchProfile() async {
    isProfileLoading.value = true;
    try {
      final response = await _apiProvider.get(ApiEndpoints.getProfile);
      final ok = ApiResponseHandler.handleResponse(response, showSuccessMessage: false);
      if (ok) {
        final data = response['data'] is Map<String, dynamic> ? Map<String, dynamic>.from(response['data'] as Map) : <String, dynamic>{};
        if (data.containsKey('iss')) {
          data['iss'] = _sanitizeUrl(data['iss']?.toString());
        }
        profile.value = data;
      }
    } catch (error) {
      ApiResponseHandler.showErrorSnackbar(error.toString());
    } finally {
      isProfileLoading.value = false;
    }
  }

  Future<void> scanItem({bool viaCamera = false}) async {
    isScanning.value = true;
    try {
      final payload = {'qrcode': scanQrcodeController.text.trim(), 'code': scanCodeController.text.trim()};
      final response = await _apiProvider.post(ApiEndpoints.scanQrcode, data: payload);
      final ok = ApiResponseHandler.handleResponse(response, showErrorMessage: true);
      if (ok) {
        final data = response['data'] is Map<String, dynamic> ? Map<String, dynamic>.from(response['data'] as Map) : <String, dynamic>{};
        scanResult.value = data;
        showStoreForm.value = !viaCamera;
        if (viaCamera) {
          storeQuantityController.text = '1';
        }
      }
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> scanItemCode() => scanItem(viaCamera: false);
  Future<void> scanItemCamera() => scanItem(viaCamera: true);

  Future<void> copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      ApiResponseHandler.showSuccessSnackbar('Copied to clipboard');
    } catch (_) {}
  }

  Future<void> openUrl(String url) async {
    final link = _sanitizeUrl(url);
    if (link.isEmpty) {
      ApiResponseHandler.showErrorSnackbar('Invalid link');
      return;
    }
    try {
      final uri = Uri.parse(link);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        await _downloadFile(link);
      }
    } catch (error) {
      await _downloadFile(link);
    }
  }

  Future<void> _downloadFile(String link) async {
    try {
      final name = link.split('/').isNotEmpty ? link.split('/').last : '';
      final fileName = name.isEmpty ? '${DateTime.now().millisecondsSinceEpoch}.file' : name;
      final dir = Directory.systemTemp;
      final filePath = '${dir.path}${Platform.pathSeparator}$fileName';
      final dio = Dio();
      final response = await dio.get<List<int>>(
        link,
        options: Options(responseType: ResponseType.bytes, followRedirects: true, validateStatus: (status) => status != null && status < 500),
      );
      final bytes = response.data ?? <int>[];
      await File(filePath).writeAsBytes(bytes);
      ApiResponseHandler.showSuccessSnackbar('Downloaded: $fileName');
    } catch (_) {
      ApiResponseHandler.showErrorSnackbar('Download failed');
    }
  }

  void regenerateStoreUuid() {
    storeUuidController.text = '${DateTime.now().millisecondsSinceEpoch}';
  }

  void resetScanner() {
    scanQrcodeController.clear();
    scanCodeController.clear();
    scanResult.value = null;
    showStoreForm.value = false;
    regenerateStoreUuid();
    storeQuantityController.text = '1';
    storeNotesController.clear();
  }

  Future<void> storeScannedItem({bool resetAfter = true}) async {
    final current = scanResult.value;
    if (current == null) {
      ApiResponseHandler.showErrorSnackbar('Scan an item first');
      return;
    }
    final itemId = current['item_id']?.toString() ?? '';
    final itemCode = current['item_code']?.toString() ?? '';
    if (itemId.isEmpty) {
      ApiResponseHandler.showErrorSnackbar('Invalid item');
      return;
    }
    final qtyStr = storeQuantityController.text.trim();
    final qty = int.tryParse(qtyStr) ?? 0;
    if (qty <= 0) {
      ApiResponseHandler.showErrorSnackbar('Enter a valid quantity');
      return;
    }
    isStoring.value = true;
    try {
      final payload = {'uuid': storeUuidController.text.trim().isEmpty ? '${DateTime.now().millisecondsSinceEpoch}' : storeUuidController.text.trim(), 'item_id': itemId, 'item_code': itemCode, 'quantity': qtyStr, 'notes': storeNotesController.text.trim()};
      final response = await _apiProvider.post(ApiEndpoints.stockStoreCreate, data: payload);
      final ok = ApiResponseHandler.handleResponse(response, showErrorMessage: false);
      if (ok) {
        if (resetAfter) {
          resetScanner();
        }
        fetchStockList(refresh: true);
      }
    } finally {
      isStoring.value = false;
    }
  }

  // ignore: unnecessary_overrides
  @override
  void onInit() {
    super.onInit();
    fetchProfile();
    fetchStockList(refresh: true);
  }

  @override
  void onClose() {
    scanQrcodeController.dispose();
    scanCodeController.dispose();
    storeUuidController.dispose();
    storeQuantityController.dispose();
    storeNotesController.dispose();
    super.onClose();
  }
}
