import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../auth/controllers/auth_controller.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/providers/api_provider.dart';
import '../../routes/app_routes.dart';

class HomeController extends GetxController {
  final AuthController authController = Get.find<AuthController>();
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, dynamic>? get user => authController.user.value;

  final isProfileLoading = false.obs;
  final profile = Rx<Map<String, dynamic>?>(null);
  final isScanning = false.obs;
  final scanResult = Rx<Map<String, dynamic>?>(null);
  final scanQrcodeController = TextEditingController();
  final scanCodeController = TextEditingController();
  final isStoring = false.obs;
  final storeUuidController = TextEditingController(text: '${DateTime.now().millisecondsSinceEpoch}');
  final storeQuantityController = TextEditingController(text: '1');
  final storeNotesController = TextEditingController();

  final isLoadingStock = false.obs;
  final stockList = <Map<String, dynamic>>[].obs;
  final stockOffset = 0.obs;
  final stockTotal = 0.obs;

  Future<void> fetchStockList({bool refresh = false}) async {
    if (refresh) {
      stockOffset.value = 0;
      stockList.clear();
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
          'quantity': {
             'from': '',
             'to': ''
          }
        }
      };
      final response = await _apiProvider.post(ApiEndpoints.stockRead, data: payload);
      final ok = ApiResponseHandler.handleResponse(response, showSuccessMessage: false);
      if (ok) {
        final data = response['data'] is Map<String, dynamic> 
            ? Map<String, dynamic>.from(response['data'] as Map) 
            : <String, dynamic>{};
            
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

  Future<void> deleteStockItem(String id) async {
    try {
      final url = '${ApiEndpoints.stockRemove}/$id';
      final response = await _apiProvider.delete(url);
      final ok = ApiResponseHandler.handleResponse(response);
      if (ok) {
        // Refresh the list to reflect changes
        fetchStockList(refresh: true);
      }
    } catch (error) {
      ApiResponseHandler.showErrorSnackbar(error.toString());
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
        final data = response['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(response['data'] as Map)
            : <String, dynamic>{};
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
  
  Future<void> scanItem() async {
    isScanning.value = true;
    try {
      final payload = {
        'qrcode': scanQrcodeController.text.trim(),
        'code': scanCodeController.text.trim(),
      };
      final response = await _apiProvider.post(ApiEndpoints.scanQrcode, data: payload);
      final ok = ApiResponseHandler.handleResponse(response);
      if (ok) {
        final data = response['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(response['data'] as Map)
            : <String, dynamic>{};
        scanResult.value = data;
      }
    } catch (error) {
      ApiResponseHandler.showErrorSnackbar(error.toString());
    } finally {
      isScanning.value = false;
    }
  }

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
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
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
    regenerateStoreUuid();
    storeQuantityController.text = '1';
    storeNotesController.clear();
  }
  
  Future<void> storeScannedItem() async {
    final current = scanResult.value;
    if (current == null) {
      ApiResponseHandler.showErrorSnackbar('Scan an item first');
      return;
    }
    final itemId = current['item_id']?.toString() ?? '';
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
      final payload = {
        'uuid': storeUuidController.text.trim().isEmpty
            ? '${DateTime.now().millisecondsSinceEpoch}'
            : storeUuidController.text.trim(),
        'item_id': itemId,
        'quantity': qtyStr,
        'notes': storeNotesController.text.trim(),
      };
      final response = await _apiProvider.post(ApiEndpoints.stockStoreCreate, data: payload);
      final ok = ApiResponseHandler.handleResponse(response);
      if (ok) {
        resetScanner();
      }
    } catch (error) {
      ApiResponseHandler.showErrorSnackbar(error.toString());
    } finally {
      isStoring.value = false;
    }
  }

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
