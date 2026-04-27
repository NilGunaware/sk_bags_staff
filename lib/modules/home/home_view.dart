import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/permission_service.dart';
import '../../data/models/order_models.dart';
import '../../routes/app_routes.dart';
import 'home_controller.dart';
import 'scanned_item_detail_view.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = controller.user;

    return Scaffold(
      key: controller.scaffoldKey,
      backgroundColor: AppColors.scaffold,
      drawer: _DashboardDrawer(controller: controller),
      appBar: AppBar(
        leading: InkWell(
          onTap: () => controller.scaffoldKey.currentState?.openDrawer(),
          child: const Icon(Icons.line_weight_rounded, color: Colors.white),
        ),
        title: const Text(
          'Dashboard',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
        ),
        actions: [
          Obx(
            () => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () => _openCartSheet(context),
                    icon: const Icon(
                      Icons.shopping_cart_outlined,
                      color: Colors.white,
                    ),
                    tooltip: 'Cart',
                  ),
                  if (controller.cartTotalQuantity > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${controller.cartTotalQuantity}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: _showLogoutDialog,
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _buildHeader(user),
            const SizedBox(height: 16),
            _QuickActionsCard(
              onScanQr: () => _openQrLookupSheet(context),
              onOrders: () => Get.toNamed(Routes.orders),
            ),
            const SizedBox(height: 16),
            _buildPriceCategoryCard(),
            const SizedBox(height: 16),
            _buildCartSnapshotCard(),
            const SizedBox(height: 16),
            _buildServerHealthCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic>? user) {
    final name = (user?['name'] ?? 'Staff').toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, $name',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan QR, choose the pricing category, and place orders from the cart.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCategoryCard() {
    return Obx(() {
      final categories = controller.priceCategories;
      final selected = controller.selectedPriceCategory;
      final isLoading = controller.isLoadingPriceCategories.value;
      final error = controller.priceCategoryError.value;

      return _SectionCard(
        title: 'Pricing Category',
        subtitle:
            'Choose the active pricing title. The selected category price is used in item detail and cart.',
        trailing: IconButton(
          onPressed: isLoading
              ? null
              : () => controller.loadPriceCategories(refresh: true),
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : const Icon(Icons.refresh, color: AppColors.primary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null && categories.isEmpty)
              Text(
                error,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (categories.isEmpty)
              const Text(
                'No pricing categories available right now.',
                style: TextStyle(color: Colors.grey),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories
                      .map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Text(category.categoryName),
                            selected:
                                selected?.categoryNo == category.categoryNo,
                            onSelected: (_) =>
                                controller.selectPriceCategory(category),
                            selectedColor: const Color(0xFF121212),
                            backgroundColor: const Color(0xFFF6F6F6),
                            labelStyle: TextStyle(
                              color: selected?.categoryNo == category.categoryNo
                                  ? Colors.white
                                  : AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                            side: BorderSide(
                              color: selected?.categoryNo == category.categoryNo
                                  ? AppColors.primary
                                  : Colors.black12,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            if (selected != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sell_outlined, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${selected.categoryName} selected',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'Slot ${selected.slotId}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildCartSnapshotCard() {
    return Obx(() {
      return _SectionCard(
        title: 'Current Cart',
        subtitle: 'Review added items or place the order from the cart button.',
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'Items',
                    value: '${controller.cartCount}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryTile(
                    label: 'Total Qty',
                    value: '${controller.cartTotalQuantity}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryTile(
                    label: 'Amount',
                    value: _formatAmount(controller.cartTotalAmount),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openCartSheet(Get.context!),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Open Cart'),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildServerHealthCard() {
    return Obx(() {
      final states = controller.serverHealthStates;
      final lastChecked = controller.lastServerHealthCheck.value;
      final isChecking = controller.isCheckingServerHealth.value;

      return _SectionCard(
        title: 'Server Health',
        subtitle: lastChecked == null
            ? 'Checking ${ApiEndpoints.ahmLabel} and ${ApiEndpoints.bhuLabel}...'
            : 'Last checked at ${_formatTime(lastChecked)}',
        trailing: IconButton(
          onPressed: isChecking
              ? null
              : () => controller.checkItemServersHealth(showLoading: true),
          icon: isChecking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : const Icon(Icons.refresh, color: AppColors.primary),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ServerHealthTile(
                label: ApiEndpoints.ahmLabel,
                isOnline: states[ApiEndpoints.ahmLabel],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ServerHealthTile(
                label: ApiEndpoints.bhuLabel,
                isOnline: states[ApiEndpoints.bhuLabel],
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _openQrLookupSheet(BuildContext context) async {
    final hasCamera =
        await PermissionService.instance.checkCameraPermission() ||
        await PermissionService.instance.requestCameraPermission();

    if (!context.mounted) {
      return;
    }

    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QrLookupSheet(cameraEnabled: hasCamera),
    );

    if (value == null || value.trim().isEmpty) {
      return;
    }

    final detail = await controller.fetchItemDetailByLookup(value);
    if (detail == null) {
      return;
    }

    Get.to(() => ScannedItemDetailView(detail: detail));
  }

  Future<void> _openCartSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _CartSheet(controller: controller),
      ),
    );
  }

  void _showLogoutDialog() {
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
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
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        controller.logout();
                      },
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

class _DashboardDrawer extends StatelessWidget {
  const _DashboardDrawer({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
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
                          child: const Icon(
                            Icons.person,
                            color: AppColors.primary,
                          ),
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
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _DrawerInfoTile(
                      icon: Icons.person_outline,
                      label: 'Name',
                      value: data?['name'],
                    ),
                    _DrawerInfoTile(
                      icon: Icons.phone_android,
                      label: 'Mobile',
                      value: data?['mobile_no'],
                    ),
                    _DrawerInfoTile(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: data?['email'],
                    ),
                    _DrawerInfoTile(
                      icon: Icons.verified_user_outlined,
                      label: 'Type',
                      value: data?['type'],
                    ),
                    _DrawerInfoTile(
                      icon: Icons.calendar_today_outlined,
                      label: 'Financial Year',
                      value: data?['financial_year'],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.receipt_long_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Orders',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      subtitle: const Text('Open remote order list'),
                      onTap: () {
                        Get.back();
                        Get.toNamed(Routes.orders);
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
}

class _DrawerInfoTile extends StatelessWidget {
  const _DrawerInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final text = value == null || value.toString().trim().isEmpty
        ? '—'
        : value.toString();
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      subtitle: Text(text),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({required this.onScanQr, required this.onOrders});

  final VoidCallback onScanQr;
  final VoidCallback onOrders;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Quick Actions',
      subtitle: 'Start scanning or open the order list directly.',
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onScanQr,
              icon: const Icon(Icons.qr_code_scanner_outlined),
              label: const Text('Scan QR'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 54)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onOrders,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Order List'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerHealthTile extends StatelessWidget {
  const _ServerHealthTile({required this.label, required this.isOnline});

  final String label;
  final bool? isOnline;

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    final String statusText;

    if (isOnline == true) {
      dotColor = const Color(0xFF1F9D55);
      statusText = 'Running';
    } else if (isOnline == false) {
      dotColor = const Color(0xFFD64545);
      statusText = 'Stopped';
    } else {
      dotColor = Colors.grey;
      statusText = 'Checking';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    color: isOnline == true
                        ? const Color(0xFF1F9D55)
                        : isOnline == false
                        ? const Color(0xFFD64545)
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrLookupSheet extends StatefulWidget {
  const _QrLookupSheet({required this.cameraEnabled});

  final bool cameraEnabled;

  @override
  State<_QrLookupSheet> createState() => _QrLookupSheetState();
}

class _QrLookupSheetState extends State<_QrLookupSheet> {
  late final MobileScannerController cameraController;
  late final TextEditingController inputController;
  bool didReturnValue = false;

  @override
  void initState() {
    super.initState();
    cameraController = MobileScannerController();
    inputController = TextEditingController();
  }

  @override
  void dispose() {
    cameraController.dispose();
    inputController.dispose();
    super.dispose();
  }

  void _complete(String value) {
    if (didReturnValue) {
      return;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    didReturnValue = true;
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Scan QR or Enter Code',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use the camera or type the QR/item code manually.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.cameraEnabled
                    ? MobileScanner(
                        controller: cameraController,
                        onDetect: (capture) {
                          final barcodes = capture.barcodes;
                          final value = barcodes.isNotEmpty
                              ? (barcodes.first.rawValue ?? '')
                              : '';
                          if (value.isNotEmpty) {
                            _complete(value);
                          }
                        },
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            'Camera permission is not available on this device. Enter the QR code manually below.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: inputController,
                textInputAction: TextInputAction.search,
                onSubmitted: _complete,
                decoration: InputDecoration(
                  labelText: 'QR Code / Item Code',
                  hintText: 'Enter QR or item code',
                  prefixIcon: const Icon(Icons.qr_code_2_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _complete(inputController.text),
                  icon: const Icon(Icons.search),
                  label: const Text('Search Item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartSheet extends StatefulWidget {
  const _CartSheet({required this.controller});

  final HomeController controller;

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  late final TextEditingController partyNameController;
  late final TextEditingController partyMobileController;

  @override
  void initState() {
    super.initState();
    partyNameController = TextEditingController();
    partyMobileController = TextEditingController();
  }

  @override
  void dispose() {
    partyNameController.dispose();
    partyMobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Obx(() {
          final items = controller.cartService.items.toList();
          final selectedCategory = controller.selectedPriceCategory;
          final totalAmount = controller.cartTotalAmount;

          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    const Text(
                      'Cart',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selectedCategory == null
                          ? 'No pricing category selected.'
                          : 'Selected price: ${selectedCategory.categoryName}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    if (items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.grey.shade400,
                              size: 40,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Cart is empty',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Scan a QR code and add items to place an order.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      for (final item in items) ...[
                        _CartItemCard(
                          item: item,
                          selectedPrice: item.priceFor(selectedCategory),
                          onDecrease: item.quantity > 1
                              ? () => controller.updateCartItemQuantity(
                                  item,
                                  item.quantity - 1,
                                )
                              : null,
                          onIncrease: item.quantity < item.availableQuantity
                              ? () => controller.updateCartItemQuantity(
                                  item,
                                  item.quantity + 1,
                                )
                              : null,
                          onRemove: () => controller.removeCartItem(item),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          children: [
                            _CartTotalRow(
                              label: 'Items',
                              value: '${controller.cartCount}',
                            ),
                            const SizedBox(height: 10),
                            _CartTotalRow(
                              label: 'Total Qty',
                              value: '${controller.cartTotalQuantity}',
                            ),
                            const SizedBox(height: 10),
                            _CartTotalRow(
                              label: 'Amount',
                              value: _formatAmount(totalAmount),
                              emphasized: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: partyNameController,
                        decoration: InputDecoration(
                          labelText: 'Party Name',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: partyMobileController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Mobile No',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: controller.cartCount == 0
                                  ? null
                                  : controller.clearCart,
                              child: const Text('Clear Cart'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.isPlacingCartOrder.value
                                  ? null
                                  : () async {
                                      final placed = await controller
                                          .placeCartOrder(
                                            partyName: partyNameController.text,
                                            partyMobile:
                                                partyMobileController.text,
                                          );
                                      if (placed && context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                              child: controller.isPlacingCartOrder.value
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Place Order'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.selectedPrice,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final CartItemModel item;
  final ItemPriceModel selectedPrice;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 62,
                  height: 62,
                  color: AppColors.primary.withValues(alpha: 0.06),
                  child: item.imageUrl == null || item.imageUrl!.isEmpty
                      ? const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.primary,
                        )
                      : Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.image_not_supported_outlined,
                                color: AppColors.primary,
                              ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Code ${item.itemCode} • ${selectedPrice.categoryName}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Price ${_formatAmount(selectedPrice.finalPrice)} • Available ${item.availableQuantity}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QtyIconButton(icon: Icons.remove, onTap: onDecrease),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              _QtyIconButton(icon: Icons.add, onTap: onIncrease),
              const Spacer(),
              Text(
                _formatAmount(selectedPrice.finalPrice * item.quantity),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyIconButton extends StatelessWidget {
  const _QtyIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.grey.shade200
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? Colors.grey : AppColors.primary,
        ),
      ),
    );
  }
}

class _CartTotalRow extends StatelessWidget {
  const _CartTotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
            fontSize: emphasized ? 18 : 15,
          ),
        ),
      ],
    );
  }
}

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

String _formatAmount(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);
