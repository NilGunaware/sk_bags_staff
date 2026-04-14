import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  Future<bool> checkCameraPermission() async {
    if (Platform.isIOS || Platform.isMacOS) return true;
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  Future<bool> requestCameraPermission() async {
    if (Platform.isIOS || Platform.isMacOS) return true;
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> ensureCameraPermission() async {
    if (Platform.isIOS || Platform.isMacOS) return true;
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final requestStatus = await Permission.camera.request();
    return requestStatus.isGranted;
  }
}
