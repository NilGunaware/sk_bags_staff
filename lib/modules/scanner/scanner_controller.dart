import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerController extends GetxController with WidgetsBindingObserver {
  final MobileScannerController cameraController = MobileScannerController();
  final RxBool isScanning = true.obs;
  bool _isClosing = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> onDetect(BuildContext context, BarcodeCapture capture) async {
    if (!isScanning.value || _isClosing) return;

    final barcodes = capture.barcodes;
    final value = barcodes.isNotEmpty ? (barcodes.first.rawValue ?? '') : '';

    if (value.isNotEmpty) {
      await closeScanner(context, result: value);
    }
  }

  Future<void> closeScanner(BuildContext context, {String? result}) async {
    if (_isClosing) return;
    _isClosing = true;
    isScanning.value = false;
    try {
      await cameraController.stop();
    } catch (_) {
      // The camera may already be stopped while the route is closing.
    }
    if (context.mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isClosing) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      cameraController.stop();
      return;
    }
    if (state == AppLifecycleState.resumed && isScanning.value) {
      cameraController.start();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController.dispose();
    super.onClose();
  }
}
