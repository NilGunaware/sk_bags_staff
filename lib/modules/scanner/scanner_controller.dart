import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerController extends GetxController {
  final MobileScannerController cameraController = MobileScannerController();
  final RxBool isScanning = true.obs;

  void onDetect(BuildContext context, BarcodeCapture capture) {
    if (!isScanning.value) return;

    final barcodes = capture.barcodes;
    final value = barcodes.isNotEmpty ? (barcodes.first.rawValue ?? '') : '';

    if (value.isNotEmpty) {
      isScanning.value = false;
      Navigator.of(context).pop(value);
    }
  }

  @override
  void onClose() {
    cameraController.dispose();
    super.onClose();
  }
}
