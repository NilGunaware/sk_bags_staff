import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/services/local_item_sync_service.dart';
import '../../core/services/order_cart_service.dart';
import '../../core/services/order_service.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/order_models.dart';
import '../../data/providers/api_provider.dart';
import '../../routes/app_routes.dart';
import '../auth/controllers/auth_controller.dart';

enum DashboardModule { physicalStock, billing, liveStock }

class HomeController extends GetxController {
  final AuthController authController = Get.find<AuthController>();
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  final LocalItemSyncService _itemSyncService =
      Get.find<LocalItemSyncService>();
  final OrderService _orderService = Get.find<OrderService>();
  final OrderCartService cartService = Get.find<OrderCartService>();
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, dynamic>? get user => authController.user.value;

  final isProfileLoading = false.obs;
  final isDeletingItem = false.obs;
  final profile = Rx<Map<String, dynamic>?>(null);
  final isScanning = false.obs;
  final scanResult = Rx<Map<String, dynamic>?>(null);
  final scanQrcodeController = TextEditingController();
  final scanCodeController = TextEditingController();
  final scanCodeFocusNode = FocusNode();
  final isStoring = false.obs;
  final showStoreForm = false.obs;
  final storeUuidController = TextEditingController(
    text: '${DateTime.now().millisecondsSinceEpoch}',
  );
  final storeQuantityController = TextEditingController(text: '1');
  final storeNotesController = TextEditingController();

  final isLoadingStock = false.obs;
  final stockList = <Map<String, dynamic>>[].obs;
  final stockOffset = 0.obs;
  final stockTotal = 0.obs;
  final serverHealthStates = <String, bool?>{
    ApiEndpoints.ahmLabel: null,
    ApiEndpoints.bhuLabel: null,
  }.obs;
  final isCheckingServerHealth = false.obs;
  final lastServerHealthCheck = Rxn<DateTime>();
  final isLoadingPriceCategories = false.obs;
  final priceCategoryError = RxnString();
  final isLookingUpItem = false.obs;
  final isPlacingCartOrder = false.obs;
  final activeDashboardModule = DashboardModule.physicalStock.obs;

  Timer? _serverHealthTimer;

  List<PriceCategoryModel> get priceCategories => cartService.priceCategories;
  PriceCategoryModel? get selectedPriceCategory =>
      cartService.selectedPriceCategory.value;
  int get cartCount => cartService.lineCount;
  int get cartTotalQuantity => cartService.totalQuantity;
  double get cartTotalAmount => cartService.totalAmount;

  void setActiveDashboardModule(DashboardModule module) {
    activeDashboardModule.value = module;
  }

  bool canDeleteStockItem(Map<String, dynamic> item) {
    return item['is_delete']?.toString() == '1';
  }

  Future<void> loadPriceCategories({bool refresh = false}) async {
    if (isLoadingPriceCategories.value && !refresh) {
      return;
    }

    isLoadingPriceCategories.value = true;
    try {
      priceCategoryError.value = null;
      final categories = await _itemSyncService.fetchPriceCategories();
      cartService.setPriceCategories(categories);
      if (categories.isEmpty) {
        priceCategoryError.value = 'No pricing categories available.';
      }
    } catch (_) {
      priceCategoryError.value =
          'Pricing categories are unavailable right now.';
    } finally {
      isLoadingPriceCategories.value = false;
    }
  }

  void selectPriceCategory(PriceCategoryModel category) {
    cartService.selectPriceCategory(category);
  }

  Future<MergedItemDetailModel?> fetchItemDetailByLookup(
    String lookup, {
    bool showErrors = true,
  }) async {
    final trimmedLookup = lookup.trim();
    if (trimmedLookup.isEmpty) {
      if (showErrors) {
        ApiResponseHandler.showErrorSnackbar('Enter a QR code or item code');
      }
      return null;
    }

    isLookingUpItem.value = true;
    try {
      return await _itemSyncService.fetchItemDetailByLookup(trimmedLookup);
    } catch (error) {
      if (showErrors) {
        ApiResponseHandler.showErrorSnackbar(_friendlyLookupMessage(error));
      }
      return null;
    } finally {
      isLookingUpItem.value = false;
    }
  }

  void addToCart(
    MergedItemDetailModel detail, {
    int quantity = 1,
    bool showSuccessMessage = true,
  }) {
    cartService.addFromDetail(detail, quantity: quantity);
    if (showSuccessMessage) {
      ApiResponseHandler.showSuccessSnackbar('Added to cart');
    }
  }

  void updateCartItemQuantity(CartItemModel item, int quantity) {
    cartService.updateQuantity(item, quantity);
  }

  void removeCartItem(CartItemModel item) {
    cartService.removeItem(item);
  }

  void clearCart() {
    cartService.clear();
  }

  Future<bool> placeCartOrder({
    required String partyName,
    required String partyMobile,
  }) async {
    final trimmedName = partyName.trim();
    final trimmedMobile = partyMobile.trim();
    if (trimmedName.isEmpty) {
      ApiResponseHandler.showErrorSnackbar('Party name is required');
      return false;
    }
    if (trimmedMobile.isEmpty || trimmedMobile.length < 10) {
      ApiResponseHandler.showErrorSnackbar('Enter a valid mobile no');
      return false;
    }
    if (cartService.items.isEmpty) {
      ApiResponseHandler.showErrorSnackbar('Cart is empty');
      return false;
    }

    isPlacingCartOrder.value = true;
    try {
      final nextEntryNo = await _orderService.suggestNextEntryNo();
      final draftItems = cartService.items
          .map(
            (item) => DraftOrderItem(
              itemCode: item.itemCode,
              itemName: item.itemName,
              availableQuantity: item.availableQuantity,
              quantity: item.quantity,
            ),
          )
          .toList();

      final response = await _orderService.createOrder(
        uuid: DateTime.now().millisecondsSinceEpoch.toString(),
        entryNo: nextEntryNo,
        entryDate: _entryDate,
        partyName: trimmedName,
        partyMobile: trimmedMobile,
        items: draftItems,
      );

      if (_orderService.isSuccessResponse(response)) {
        final message = _orderService.extractMessage(response);
        cartService.clear();
        ApiResponseHandler.showSuccessSnackbar(
          message.isEmpty ? 'Order created successfully' : message,
        );
        return true;
      }

      ApiResponseHandler.showErrorSnackbar(
        _orderService.extractMessage(response).isEmpty
            ? 'Could not create order'
            : _orderService.extractMessage(response),
      );
      return false;
    } catch (_) {
      ApiResponseHandler.showErrorSnackbar('Could not create order');
      return false;
    } finally {
      isPlacingCartOrder.value = false;
    }
  }

  String selectedPriceLabelFor(MergedItemDetailModel detail) {
    final category = selectedPriceCategory;
    return detail.priceFor(category).displayName;
  }

  double selectedPriceForDetail(MergedItemDetailModel detail) {
    return detail.priceFor(selectedPriceCategory).finalPrice;
  }

  double selectedPriceForCartItem(CartItemModel item) {
    return item.priceFor(selectedPriceCategory).finalPrice;
  }

  String _friendlyLookupMessage(Object error) {
    final text = error.toString().trim();
    if (text.isEmpty) {
      return 'Item lookup is unavailable right now.';
    }
    final lower = text.toLowerCase();
    if (lower.contains('unavailable') || lower.contains('connection')) {
      return 'Item servers are unavailable right now. Check the dashboard status.';
    }
    if (lower.contains('no item matched') || lower.contains('not found')) {
      return 'No item matched this QR code.';
    }
    return text;
  }

  String get _entryDate =>
      '${DateTime.now().year}-'
      '${DateTime.now().month.toString().padLeft(2, '0')}-'
      '${DateTime.now().day.toString().padLeft(2, '0')}';

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
      final response = await _apiProvider.post(
        ApiEndpoints.stockRead,
        data: payload,
      );
      final ok = ApiResponseHandler.handleResponse(
        response,
        showSuccessMessage: false,
      );
      if (ok) {
        final data = response['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(response['data'] as Map)
            : <String, dynamic>{};

        stockTotal.value = int.tryParse(data['total']?.toString() ?? '0') ?? 0;
        final records = data['record'];
        if (records is List) {
          final list = records
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          stockList.addAll(list);
          stockOffset.value += list.length;
        }
      }
    } catch (error) {
      // ApiResponseHandler.showErrorSnackbar(error.toString());
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
        final payload = {
          'qrcode': scanQrcodeController.text.trim(),
          'code': scanCodeController.text.trim(),
        };
        final response = await _apiProvider.post(
          ApiEndpoints.scanQrcode,
          data: payload,
        );
        final ok = ApiResponseHandler.handleResponse(
          response,
          showErrorMessage: true,
        );
        if (!ok) return;
        final data = response['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(response['data'] as Map)
            : <String, dynamic>{};
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
      final payloadStore = {
        'uuid': storeUuidController.text.trim().isEmpty
            ? '${DateTime.now().millisecondsSinceEpoch}'
            : storeUuidController.text.trim(),
        'item_id': itemId,
        'item_code': itemCode,
        'quantity': qtyStr,
        'notes': storeNotesController.text.trim(),
      };
      final responseStore = await _apiProvider.post(
        ApiEndpoints.stockStoreCreate,
        data: payloadStore,
      );
      final okStore = ApiResponseHandler.handleResponse(
        responseStore,
        showErrorMessage: true,
      );
      if (okStore) {
        resetScanner();
        // Add a small delay to ensure backend has processed the transaction
        await Future.delayed(const Duration(milliseconds: 500));
        await fetchStockList(refresh: true);

        // Request focus back to code input field
        scanCodeFocusNode.requestFocus();
      }
    } catch (e) {
      // ApiResponseHandler.showErrorSnackbar(e.toString());
    } finally {
      isStoring.value = false;
    }
  }

  Future<bool> deleteStockItem(String id) async {
    try {
      final url = '${ApiEndpoints.stockRemove}/$id';
      final response = await _apiProvider.delete(url);
      final ok = ApiResponseHandler.handleResponse(
        response,
        showErrorMessage: true,
        showSuccessMessage: false,
      );
      if (ok) {
        await fetchStockList(refresh: true);
        return true;
      }
      return false;
    } catch (error) {
      // ApiResponseHandler.showErrorSnackbar(error.toString());
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
      final ok = ApiResponseHandler.handleResponse(
        response,
        showSuccessMessage: false,
      );
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
      // ApiResponseHandler.showErrorSnackbar(error.toString());
    } finally {
      isProfileLoading.value = false;
    }
  }

  Future<void> scanItem({bool viaCamera = false}) async {
    isScanning.value = true;
    try {
      final payload = {
        'qrcode': scanQrcodeController.text.trim(),
        'code': scanCodeController.text.trim(),
      };
      final response = await _apiProvider.post(
        ApiEndpoints.scanQrcode,
        data: payload,
      );
      final ok = ApiResponseHandler.handleResponse(
        response,
        showErrorMessage: true,
      );
      if (ok) {
        final data = response['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(response['data'] as Map)
            : <String, dynamic>{};
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
      final fileName = name.isEmpty
          ? '${DateTime.now().millisecondsSinceEpoch}.file'
          : name;
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

  Future<void> checkItemServersHealth({bool showLoading = false}) async {
    if (showLoading) {
      isCheckingServerHealth.value = true;
    }

    try {
      final results = await Future.wait<bool>([
        _checkServerHealth(ApiEndpoints.ahmItemsBaseUrl),
        _checkServerHealth(ApiEndpoints.bhuItemsBaseUrl),
      ]);

      serverHealthStates.assignAll(<String, bool?>{
        ApiEndpoints.ahmLabel: results[0],
        ApiEndpoints.bhuLabel: results[1],
      });
      lastServerHealthCheck.value = DateTime.now();
    } finally {
      isCheckingServerHealth.value = false;
    }
  }

  Future<bool> _checkServerHealth(String baseUrl) async {
    final uri = Uri.parse('$baseUrl/health');
    _logApiRequest('GET', uri, body: <String, dynamic>{});
    try {
      final response = await Dio().get<Map<String, dynamic>>(
        uri.toString(),
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
          headers: const <String, dynamic>{'Accept': 'application/json'},
        ),
      );
      _logApiResponse(
        'GET',
        uri,
        response.statusCode ?? 0,
        response.data ?? <String, dynamic>{},
      );

      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } catch (error) {
      debugPrint('========== DASHBOARD API RESPONSE ==========');
      debugPrint('GET $uri [ERROR]');
      debugPrint('Body: ${_formatJsonForLog({'error': error.toString()})}');
      return false;
    }
  }

  void _logApiRequest(String method, Uri uri, {Object? body}) {
    debugPrint('========== DASHBOARD API REQUEST ==========');
    debugPrint('$method $uri');
    debugPrint('Body: ${_formatJsonForLog(body ?? <String, dynamic>{})}');
  }

  void _logApiResponse(String method, Uri uri, int statusCode, Object? body) {
    debugPrint('========== DASHBOARD API RESPONSE ==========');
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
      final payload = {
        'uuid': storeUuidController.text.trim().isEmpty
            ? '${DateTime.now().millisecondsSinceEpoch}'
            : storeUuidController.text.trim(),
        'item_id': itemId,
        'item_code': itemCode,
        'quantity': qtyStr,
        'notes': storeNotesController.text.trim(),
      };
      final response = await _apiProvider.post(
        ApiEndpoints.stockStoreCreate,
        data: payload,
      );
      final ok = ApiResponseHandler.handleResponse(
        response,
        showErrorMessage: false,
      );
      if (ok) {
        if (resetAfter) {
          resetScanner();
        }
        await fetchStockList(refresh: true);
      }
    } catch (e) {
      // ApiResponseHandler.showErrorSnackbar(e.toString());
    } finally {
      isStoring.value = false;
    }
  }

  // ignore: unnecessary_overrides
  @override
  void onInit() {
    super.onInit();
    fetchProfile();
    loadPriceCategories();
    fetchStockList(refresh: true);
    checkItemServersHealth(showLoading: true);
    _serverHealthTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkItemServersHealth(),
    );
  }

  @override
  void onClose() {
    _serverHealthTimer?.cancel();
    scanQrcodeController.dispose();
    scanCodeController.dispose();
    scanCodeFocusNode.dispose();
    storeUuidController.dispose();
    storeQuantityController.dispose();
    storeNotesController.dispose();
    super.onClose();
  }
}
