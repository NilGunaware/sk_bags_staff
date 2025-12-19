import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

}
