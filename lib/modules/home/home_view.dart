import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/services/permission_service.dart';

import '../../core/constants/app_colors.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = controller.user;

    return Scaffold(
      key: controller.scaffoldKey,
      backgroundColor: AppColors.scaffold,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        leading: InkWell(
          onTap: () {
            controller.scaffoldKey.currentState?.openDrawer();
          },
          child: const Icon(
            Icons.line_weight_rounded,
            color: Colors.white,
          ),
        ),
          title: const Text(
            "Dashboard",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Logout',
            ),
          ],
          elevation: 0,
        ),


        body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, user),
              const SizedBox(height: 24),
              _buildScannerCard(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Obx(() {
          final data = controller.profile.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppColors.primary,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.person, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (data?['name'] ?? '—').toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                (data?['type'] ?? '—').toString(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Powered by Interlink Consultant',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                      child: controller.isProfileLoading.value && data == null
                          ? const Center(child: Padding(
                              padding: EdgeInsets.all(16), 
                              child: CircularProgressIndicator(color: AppColors.primary)))
                          : Column(
                              children: [
                                Expanded(
                                  child: ListView(
                                    padding: const EdgeInsets.all(16),
                                    children: [
                                      _infoTile(Icons.badge, 'ID', data?['id']),
                                      _infoTile(Icons.person_outline, 'Name', data?['name']),
                                      _infoTile(Icons.phone_android, 'Mobile', data?['mobile_no']),
                                      _infoTile(Icons.email_outlined, 'Email', data?['email']),
                                      _infoTile(Icons.verified_user_outlined, 'Type', data?['type']),
                                      _infoTile(Icons.admin_panel_settings_outlined, 'Role ID', data?['role_id']),
                                      _infoTile(Icons.store_outlined, 'Branch ID', data?['branch_id']),
                                      _infoTile(Icons.calendar_today_outlined, 'Financial Year', data?['financial_year']),
                                      _infoTile(Icons.timer_outlined, 'Expiry Time (sec)', data?['expiry_time']),
                                      _infoTile(Icons.event, 'Created At', _formatEpoch(data?['created_at'])),
                                      _linkTile(Icons.link, 'Issuer', data?['iss']),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                                  title: const Text(
                                    'Logout',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    _showLogoutDialog(context);
                                  },
                                ),
                              ],
                            ),
                    ),
            ],
          );
        }),
      ),
    );
  }

  String _formatEpoch(dynamic value) {
    if (value == null) return '—';
    try {
      final seconds = int.tryParse(value.toString());
      if (seconds == null) return '—';
      final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
             '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  Widget _infoTile(IconData icon, String label, dynamic value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      subtitle: Text((value == null || value.toString().isEmpty) ? '—' : value.toString()),
    );
  }

  Widget _linkTile(IconData icon, String label, dynamic value) {
    final txt = (value == null) ? '' : value.toString();
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      subtitle: Text(txt.isEmpty ? '—' : txt),
      trailing: txt.isEmpty ? null : IconButton(
        icon: const Icon(Icons.copy, color: AppColors.primary),
        onPressed: () => controller.copyToClipboard(txt),
        tooltip: 'Copy',
      ),
    );
  }
  Widget _buildHeader(BuildContext context, Map<String, dynamic>? user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SK Bags Staff',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stock Management System',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildScannerCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Scan QR/Barcode',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller.scanQrcodeController,
            decoration: InputDecoration(
              labelText: 'Qrcode',
              hintText: 'Enter QR value',
              prefixIcon: const Icon(Icons.qr_code_2),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller.scanCodeController,
            decoration: InputDecoration(
              labelText: 'Code',
              hintText: 'Enter item code',
              prefixIcon: const Icon(Icons.numbers),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: Obx(() => ElevatedButton.icon(
              onPressed: controller.isScanning.value ? null : controller.scanItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: controller.isScanning.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_scanner),
              label: Text(controller.isScanning.value ? 'Scanning...' : 'Scan'),
            )),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _openCameraScanner(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Camera Scan'),
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final data = controller.scanResult.value;
            if (data == null || data.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Result',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                _infoTile(Icons.sell_outlined, 'Item Code', data['item_code']),
                _infoTile(Icons.label_important_outline, 'Item Name', data['item_name']),
                _infoTile(Icons.qr_code_2, 'Item Qrcode', data['item_qrcode']),
                _infoTile(Icons.category_outlined, 'Group', data['group_name']),
                _infoTile(Icons.home_work_outlined, 'Company', data['company_name']),
                Row(
                  children: [
                    Expanded(child: _infoTile(Icons.inventory_2_outlined, 'Quantity', data['quantity'])),
                    Expanded(child: _infoTile(Icons.qr_code_scanner, 'Scanned Qty', data['scanned_quantity'])),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout, size: 48, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'Logout',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to logout?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        controller.logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Logout'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCameraScanner(BuildContext context) async {
    final ok = await PermissionService.instance.ensureCameraPermission();
    if (!ok) return;
    var handled = false;
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 300,
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent),
                ),
                clipBehavior: Clip.antiAlias,
                child: MobileScanner(
                  fit: BoxFit.cover,
                  onDetect: (capture) {
                    if (handled) return;
                    final barcodes = capture.barcodes;
                    final value = barcodes.isNotEmpty ? (barcodes.first.rawValue ?? '') : '';
                    if (value.isEmpty) return;
                    handled = true;
                    controller.scanQrcodeController.text = value;
                    Get.back();
                    controller.scanItem();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () => Get.back(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

}
