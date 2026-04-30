import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/permission_service.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/order_models.dart';
import '../../routes/app_routes.dart';
import 'home_controller.dart';
import 'live_stock_detail_view.dart';
import 'scanned_item_detail_view.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: controller.scaffoldKey,
      backgroundColor: AppColors.scaffold,
      drawer: _DashboardDrawer(controller: controller),
      appBar: AppBar(
        leading: InkWell(
          onTap: () => controller.scaffoldKey.currentState?.openDrawer(),
          child: const Icon(Icons.line_weight_rounded, color: Colors.white),
        ),
        title: const Text('Dashboard', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
        actions: [
          Obx(
            () => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () => _openCartSheet(context),
                    icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                    tooltip: 'Cart',
                  ),
                  if (controller.cartTotalQuantity > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF97316), borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          '${controller.cartTotalQuantity}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
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
            _buildDashboardToggle(),
            const SizedBox(height: 16),
            Obx(() {
              final active = controller.activeDashboardModule.value;
              if (active == DashboardModule.physicalStock) {
                return _FeatureZone(
                  title: 'Physical Stock',
                  subtitle: 'Keep the old stock workflow here: scan stock, save it, and review the saved stock records.',
                  backgroundColor: const Color(0xFFEEF7F6),
                  borderColor: const Color(0xFFA9D5CF),
                  accentColor: const Color(0xFF0F766E),
                  children: [_buildStockScannerCard(context), const SizedBox(height: 16), _buildStockListCard()],
                );
              }

              if (active == DashboardModule.billing) {
                return _FeatureZone(
                  title: 'Billing',
                  subtitle: 'Use the billing flow here: scan QR, choose pricing, review cart, and open orders.',
                  backgroundColor: const Color(0xFFFFF4EA),
                  borderColor: const Color(0xFFF4C99B),
                  accentColor: const Color(0xFFD97706),
                  headerTrailing: _CompactServerHealthStrip(controller: controller),
                  children: [
                    _QuickActionsCard(onScanQr: () => _openBillingLookupSheet(context), onOrders: () => Get.toNamed(Routes.orders)),
                    const SizedBox(height: 16),
                    _buildPriceCategoryCard(),
                    const SizedBox(height: 16),
                    _buildCartSnapshotCard(),
                  ],
                );
              }

              return _FeatureZone(
                title: 'Live Stock',
                subtitle: 'Scan QR or enter a code to view complete item details, all prices, and branch-wise live stock from AHM and BHU.',
                backgroundColor: const Color(0xFFF1F0FF),
                borderColor: const Color(0xFFC8C0FF),
                accentColor: const Color(0xFF4C1D95),
                headerTrailing: _CompactServerHealthStrip(controller: controller),
                children: [_LiveStockActionsCard(onLookup: () => _openLiveStockLookupSheet(context))],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardToggle() {
    return Obx(() {
      final active = controller.activeDashboardModule.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _DashboardMenuButton(title: 'Physical Stock', icon: Icons.inventory_2_outlined, isSelected: active == DashboardModule.physicalStock, selectedColor: const Color(0xFF0F766E), onTap: () => controller.setActiveDashboardModule(DashboardModule.physicalStock)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardMenuButton(title: 'Billing', icon: Icons.point_of_sale_outlined, isSelected: active == DashboardModule.billing, selectedColor: const Color(0xFFD97706), onTap: () => controller.setActiveDashboardModule(DashboardModule.billing)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardMenuButton(title: 'Live Stock', icon: Icons.stacked_bar_chart_outlined, isSelected: active == DashboardModule.liveStock, selectedColor: const Color(0xFF4C1D95), onTap: () => controller.setActiveDashboardModule(DashboardModule.liveStock)),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildPriceCategoryCard() {
    return Obx(() {
      final categories = controller.priceCategories;
      final selected = controller.selectedPriceCategory;
      final isLoading = controller.isLoadingPriceCategories.value;
      final error = controller.priceCategoryError.value;

      return _SectionCard(
        title: 'Pricing Category',
        subtitle: 'Choose the active pricing title. The selected category price is used in item detail and cart.',
        trailing: IconButton(
          onPressed: isLoading ? null : () => controller.loadPriceCategories(refresh: true),
          icon: isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)) : const Icon(Icons.refresh, color: AppColors.primary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null && categories.isEmpty)
              Text(
                error,
                style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
              )
            else if (categories.isEmpty)
              const Text('No pricing categories available right now.', style: TextStyle(color: Colors.grey))
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
                            selected: selected?.categoryNo == category.categoryNo,
                            onSelected: (_) => controller.selectPriceCategory(category),
                            selectedColor: const Color(0xFF121212),
                            backgroundColor: const Color(0xFFF6F6F6),
                            labelStyle: TextStyle(color: selected?.categoryNo == category.categoryNo ? Colors.white : AppColors.primary, fontWeight: FontWeight.w700),
                            side: BorderSide(color: selected?.categoryNo == category.categoryNo ? AppColors.primary : Colors.black12),
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
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    const Icon(Icons.sell_outlined, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${selected.categoryName} selected',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      'Slot ${selected.slotId}',
                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
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
                  child: _SummaryTile(label: 'Items', value: '${controller.cartCount}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryTile(label: 'Total Qty', value: '${controller.cartTotalQuantity}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryTile(label: 'Amount', value: _formatAmount(controller.cartTotalAmount)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(onPressed: () => _openCartSheet(Get.context!), icon: const Icon(Icons.shopping_bag_outlined), label: const Text('Open Cart')),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStockScannerCard(BuildContext context) {
    return _SectionCard(
      title: 'Stock Scan & Save',
      subtitle: 'Keep using the stock workflow here. Scan from the camera or enter the item code manually and save stock.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openCameraScanner(context),
              icon: const Icon(Icons.qr_code_scanner_outlined),
              label: const Text('Scan QR With Camera'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 54),
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'OR',
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller.scanCodeController,
            focusNode: controller.scanCodeFocusNode,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => controller.storeItemEnsureScan(),
            decoration: InputDecoration(
              labelText: 'Enter Item Code',
              hintText: 'Type item code',
              prefixIcon: const Icon(Icons.numbers_outlined),
              suffixIcon: Obx(
                () => IconButton(
                  onPressed: controller.isStoring.value ? null : controller.resetScanner,
                  icon: controller.isStoring.value ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.close),
                ),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
          const SizedBox(height: 12),
          Obx(() {
            final data = controller.scanResult.value;
            final showForm = controller.showStoreForm.value;
            final hideQuantity = data != null && data.isNotEmpty && !showForm;

            if (hideQuantity) {
              return const SizedBox.shrink();
            }

            return TextField(
              controller: controller.storeQuantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Quantity',
                prefixIcon: const Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
              ),
            );
          }),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Obx(
              () => ElevatedButton.icon(
                onPressed: controller.isStoring.value ? null : controller.storeItemEnsureScan,
                icon: controller.isStoring.value ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
                label: Text(controller.isStoring.value ? 'Saving...' : 'Save Stock'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 54)),
              ),
            ),
          ),
          Obx(() {
            final data = controller.scanResult.value;
            if (data == null || data.isEmpty) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scanned Item',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    _resultInfoTile(Icons.sell_outlined, 'Item Code', data['item_code']),
                    const SizedBox(height: 8),
                    _resultInfoTile(Icons.label_important_outline, 'Item Name', data['item_name']),
                    const SizedBox(height: 8),
                    _resultInfoTile(Icons.category_outlined, 'Group', data['group_name']),
                    const SizedBox(height: 8),
                    _resultInfoTile(Icons.home_work_outlined, 'Company', data['company_name']),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _resultInfoTile(Icons.inventory_2_outlined, 'Quantity', data['quantity'])),
                        const SizedBox(width: 12),
                        Expanded(child: _resultInfoTile(Icons.qr_code_scanner, 'Scanned Qty', data['scanned_quantity'])),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller.storeNotesController,
                      maxLines: 1,
                      decoration: InputDecoration(
                        labelText: 'Notes',
                        prefixIcon: const Icon(Icons.notes_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStockListCard() {
    return Obx(() {
      final isLoading = controller.isLoadingStock.value && controller.stockList.isEmpty;

      return _SectionCard(
        title: 'Stock List',
        subtitle: controller.stockTotal.value == 0 ? 'Recently saved stock records will appear here.' : '${controller.stockTotal.value} stock record(s) loaded.',
        trailing: IconButton(
          onPressed: () => controller.fetchStockList(refresh: true),
          icon: const Icon(Icons.refresh, color: AppColors.primary),
          tooltip: 'Refresh stock list',
        ),
        child: Column(
          children: [
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            else if (controller.stockList.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    const Text(
                      'No stock records found',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controller.stockList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = controller.stockList[index];
                  final canDelete = controller.canDeleteStockItem(item);

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFDFD),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.inventory_2, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['item_name']?.toString() ?? '—',
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(item['company_name']?.toString() ?? '—', style: TextStyle(color: Colors.grey.shade700)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
                              child: Text(
                                '${item['quantity'] ?? 0}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: Column(children: [_stockDetailItem(Icons.numbers, 'Code', item['code']), const SizedBox(height: 8), _stockDetailItem(Icons.qr_code, 'QR', item['qrcode'])])),
                            const SizedBox(width: 12),
                            Expanded(child: Column(children: [_stockDetailItem(Icons.category_outlined, 'Group', item['group_name']), const SizedBox(height: 8), _stockDetailItem(Icons.fingerprint, 'ID', item['id'])])),
                          ],
                        ),
                        if (canDelete) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmDelete(item),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remove Item'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            if (controller.stockList.length < controller.stockTotal.value) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: controller.isLoadingStock.value ? null : () => controller.fetchStockList(),
                child: controller.isLoadingStock.value ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Load More'),
              ),
            ],
          ],
        ),
      );
    });
  }

  Future<void> _openBillingLookupSheet(BuildContext context) async {
    final detail = await _resolveLookupDetail(context);
    if (detail == null) {
      return;
    }

    Get.to(() => ScannedItemDetailView(detail: detail));
  }

  Future<void> _openLiveStockLookupSheet(BuildContext context) async {
    final detail = await _resolveLookupDetail(context);
    if (detail == null) {
      return;
    }

    Get.to(() => LiveStockDetailView(detail: detail));
  }

  Future<MergedItemDetailModel?> _resolveLookupDetail(BuildContext context) async {
    final hasCamera = await PermissionService.instance.checkCameraPermission() || await PermissionService.instance.requestCameraPermission();

    if (!context.mounted) {
      return null;
    }

    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QrLookupSheet(cameraEnabled: hasCamera),
    );

    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final detail = await controller.fetchItemDetailByLookup(value);
    return detail;
  }

  Future<void> _openCartSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: _CartSheet(controller: controller)),
    );
  }

  Widget _resultInfoTile(IconData icon, String label, dynamic value) {
    final text = value?.toString().trim().isNotEmpty == true ? value.toString() : '—';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.primary),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: text,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stockDetailItem(IconData icon, String label, dynamic value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                TextSpan(
                  text: value?.toString() ?? '—',
                  style: TextStyle(color: Colors.grey.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _confirmDelete(Map<String, dynamic> item) {
    if (!controller.canDeleteStockItem(item)) {
      return;
    }

    showDialog<void>(
      context: Get.context!,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Delete Item',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Are you sure you want to delete this item?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Obx(() {
                  final deleting = controller.isDeletingItem.value;

                  return Row(
                    children: [
                      Expanded(
                        child: TextButton(onPressed: deleting ? null : () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: deleting
                              ? null
                              : () async {
                                  final success = await controller.deleteStockItemRecord(item);
                                  if (success && dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                    ApiResponseHandler.showSuccessSnackbar('Item deleted successfully');
                                  }
                                },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                          child: deleting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Delete'),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
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
                    child: TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
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

  Future<void> _openCameraScanner(BuildContext context) async {
    final ok = await PermissionService.instance.ensureCameraPermission();
    if (!ok) {
      return;
    }

    final scannedValue = await Get.toNamed(Routes.scanner);
    if (scannedValue is String && scannedValue.isNotEmpty) {
      controller.scanCodeController.text = scannedValue;
      await controller.scanItemCamera();
    }
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
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
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
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text((data?['type'] ?? '—').toString(), style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Powered by Interlink Consultant', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _DrawerInfoTile(icon: Icons.person_outline, label: 'Name', value: data?['name']),
                    _DrawerInfoTile(icon: Icons.phone_android, label: 'Mobile', value: data?['mobile_no']),
                    _DrawerInfoTile(icon: Icons.email_outlined, label: 'Email', value: data?['email']),
                    _DrawerInfoTile(icon: Icons.verified_user_outlined, label: 'Type', value: data?['type']),
                    _DrawerInfoTile(icon: Icons.calendar_today_outlined, label: 'Financial Year', value: data?['financial_year']),
                    const SizedBox(height: 12),
                    // const Divider(),
                    // ListTile(
                    //   leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
                    //   title: const Text(
                    //     'Orders',
                    //     style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                    //   ),
                    //   subtitle: const Text('Open remote order list'),
                    //   onTap: () {
                    //     Get.back();
                    //     Get.toNamed(Routes.orders);
                    //   },
                    // ),
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
  const _DrawerInfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final text = value == null || value.toString().trim().isEmpty ? '—' : value.toString();
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

class _LiveStockActionsCard extends StatelessWidget {
  const _LiveStockActionsCard({required this.onLookup});

  final VoidCallback onLookup;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Live Stock Lookup',
      subtitle: 'Scan QR or enter an item code to open the live stock detail screen with all prices and branch-wise server stock.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onLookup,
              icon: const Icon(Icons.qr_code_scanner_outlined),
              label: const Text('Scan QR / Search Item'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C1D95), foregroundColor: Colors.white, minimumSize: const Size(0, 54)),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF4C1D95).withValues(alpha: 0.07), borderRadius: BorderRadius.circular(16)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.inventory_2_outlined, color: Color(0xFF4C1D95), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Live Stock shows item image, all BUSY price rows, AHM/BHU totals, and branch-wise stock availability.',
                    style: TextStyle(color: Color(0xFF312E81), fontWeight: FontWeight.w600),
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

class _FeatureZone extends StatelessWidget {
  const _FeatureZone({required this.title, required this.subtitle, required this.backgroundColor, required this.borderColor, required this.accentColor, required this.children, this.headerTrailing});

  final String title;
  final String subtitle;
  final Color backgroundColor;
  final Color borderColor;
  final Color accentColor;
  final List<Widget> children;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.dashboard_customize_outlined, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: accentColor),
                    ),
                  ],
                ),
              ),
              if (headerTrailing != null) ...[const SizedBox(width: 12), headerTrailing!],
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _DashboardMenuButton extends StatelessWidget {
  const _DashboardMenuButton({required this.title, required this.icon, required this.isSelected, required this.selectedColor, required this.onTap});

  final String title;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? selectedColor : Colors.black12, width: isSelected ? 1.6 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: isSelected ? selectedColor.withValues(alpha: 0.16) : const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: selectedColor, size: 20),
                ),
                const Spacer(),
                Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: isSelected ? selectedColor : Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isSelected ? selectedColor : AppColors.primary, fontSize: 13, height: 1.2, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: isSelected ? selectedColor.withValues(alpha: 0.14) : Colors.grey.shade100, borderRadius: BorderRadius.circular(999)),
              child: Text(
                isSelected ? 'Showing' : 'Open',
                style: TextStyle(color: isSelected ? selectedColor : Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child, this.trailing});

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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
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
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CompactServerHealthStrip extends StatelessWidget {
  const _CompactServerHealthStrip({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final states = controller.serverHealthStates;
      return Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.end,
        children: [
          _CompactServerHealthDot(label: ApiEndpoints.ahmLabel, isOnline: states[ApiEndpoints.ahmLabel]),
          _CompactServerHealthDot(label: ApiEndpoints.bhuLabel, isOnline: states[ApiEndpoints.bhuLabel]),
        ],
      );
    });
  }
}

class _CompactServerHealthDot extends StatelessWidget {
  const _CompactServerHealthDot({required this.label, required this.isOnline});

  final String label;
  final bool? isOnline;

  @override
  Widget build(BuildContext context) {
    final dotColor = isOnline == true
        ? const Color(0xFF2563EB)
        : isOnline == false
        ? const Color(0xFFD64545)
        : Colors.grey.shade500;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '•',
          style: TextStyle(color: dotColor, fontSize: 18, fontWeight: FontWeight.w900, height: 1),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: dotColor, fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
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
    final normalized = _normalizeLookupValue(value);
    if (normalized.isEmpty) {
      return;
    }
    didReturnValue = true;
    Navigator.of(context).pop(normalized);
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
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(999)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Scan QR or Enter Code',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text('Use the camera or type the QR/item code manually.', style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 16),
              Container(
                height: 250,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24)),
                clipBehavior: Clip.antiAlias,
                child: widget.cameraEnabled
                    ? MobileScanner(
                        controller: cameraController,
                        onDetect: (capture) {
                          final barcodes = capture.barcodes;
                          final value = barcodes.isNotEmpty ? (barcodes.first.displayValue ?? barcodes.first.rawValue ?? '') : '';
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
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(onPressed: () => _complete(inputController.text), icon: const Icon(Icons.search), label: const Text('Search Item')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _normalizeLookupValue(String value) {
    return value.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '').trim();
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
  late final ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    partyNameController = TextEditingController();
    partyMobileController = TextEditingController();
    scrollController = ScrollController();
  }

  @override
  void dispose() {
    scrollController.dispose();
    partyNameController.dispose();
    partyMobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
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
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(999)),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset > 0 ? bottomInset + 24 : 24),
                    children: [
                      const Text(
                        'Cart',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                      const SizedBox(height: 6),
                      Text(selectedCategory == null ? 'No pricing category selected.' : 'Selected price: ${selectedCategory.categoryName}', style: TextStyle(color: Colors.grey.shade700)),
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
                              Icon(Icons.shopping_cart_outlined, color: Colors.grey.shade400, size: 40),
                              const SizedBox(height: 10),
                              const Text(
                                'Cart is empty',
                                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
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
                            onDecrease: item.quantity > 1 ? () => controller.updateCartItemQuantity(item, item.quantity - 1) : null,
                            onIncrease: item.quantity < item.availableQuantity ? () => controller.updateCartItemQuantity(item, item.quantity + 1) : null,
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
                              _CartTotalRow(label: 'Items', value: '${controller.cartCount}'),
                              const SizedBox(height: 10),
                              _CartTotalRow(label: 'Total Qty', value: '${controller.cartTotalQuantity}'),
                              const SizedBox(height: 10),
                              _CartTotalRow(label: 'Amount', value: _formatAmount(totalAmount), emphasized: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: partyNameController,
                          textInputAction: TextInputAction.next,
                          scrollPadding: const EdgeInsets.only(bottom: 180),
                          decoration: InputDecoration(
                            labelText: 'Party Name',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: partyMobileController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          scrollPadding: const EdgeInsets.only(bottom: 180),
                          decoration: InputDecoration(
                            labelText: 'Mobile No',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(onPressed: controller.cartCount == 0 ? null : controller.clearCart, child: const Text('Clear Cart')),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: controller.isPlacingCartOrder.value
                                    ? null
                                    : () async {
                                        final placed = await controller.placeCartOrder(partyName: partyNameController.text, partyMobile: partyMobileController.text);
                                        if (placed && context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      },
                                child: controller.isPlacingCartOrder.value ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Place Order'),
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
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({required this.item, required this.selectedPrice, required this.onDecrease, required this.onIncrease, required this.onRemove});

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
                      ? const Icon(Icons.image_not_supported_outlined, color: AppColors.primary)
                      : Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported_outlined, color: AppColors.primary),
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
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                    const SizedBox(height: 6),
                    Text('Code ${item.itemCode} • ${selectedPrice.categoryName}', style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 6),
                    Text(
                      'Price ${_formatAmount(selectedPrice.finalPrice)} • Available ${item.availableQuantity}',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
              _QtyIconButton(icon: Icons.add, onTap: onIncrease),
              const Spacer(),
              Text(
                _formatAmount(selectedPrice.finalPrice * item.quantity),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
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
        decoration: BoxDecoration(color: onTap == null ? Colors.grey.shade200 : AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 18, color: onTap == null ? Colors.grey : AppColors.primary),
      ),
    );
  }
}

class _CartTotalRow extends StatelessWidget {
  const _CartTotalRow({required this.label, required this.value, this.emphasized = false});

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
          style: TextStyle(color: AppColors.primary, fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700, fontSize: emphasized ? 18 : 15),
        ),
      ],
    );
  }
}

String _formatAmount(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
