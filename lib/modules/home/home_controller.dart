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

  @override
  void onInit() {
    super.onInit();
    fetchProfile();
  }

  @override
  void onClose() {
    scanQrcodeController.dispose();
    scanCodeController.dispose();
    super.onClose();
  }
}
