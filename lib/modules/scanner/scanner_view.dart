import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';
import 'scanner_controller.dart';

class ScannerView extends GetView<ScannerController> {
  const ScannerView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          controller.closeScanner(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => controller.closeScanner(context),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Scan QR Code'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: controller.cameraController,
              onDetect: (capture) => controller.onDetect(context, capture),
              errorBuilder: (context, error) {
                return Center(
                  child: Text(
                    'Error: ${error.errorCode}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              },
            ),
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
