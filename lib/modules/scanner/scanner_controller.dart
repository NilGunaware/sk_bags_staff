import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerController extends GetxController {
  final MobileScannerController cameraController = MobileScannerController();
  var isScanning = true.obs;

  void onDetect(BarcodeCapture capture) {
    if (!isScanning.value) return;

    final barcodes = capture.barcodes;
    final value = barcodes.isNotEmpty ? (barcodes.first.rawValue ?? '') : '';

    if (value.isNotEmpty) {
      isScanning.value = false;
      Get.back(result: value);
    }
  }

  @override
  void onClose() {
    cameraController.dispose();
    super.onClose();
  }
}
