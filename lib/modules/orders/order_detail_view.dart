import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/order_models.dart';
import 'order_detail_controller.dart';

class OrderDetailView extends GetView<OrderDetailController> {
  const OrderDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(title: const Text('Order Details')),
      body: SafeArea(
        child: Obx(() {
          final detail = controller.detail.value;
          final summary = detail?.summary ?? controller.order.value;

          if (summary == null && controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (summary == null) {
            return const _DetailEmptyState(
              icon: Icons.error_outline,
              title: 'Order not found',
              subtitle: 'Open the order again from the order list.',
            );
          }

          return RefreshIndicator(
            onRefresh: controller.fetchDetail,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _DetailHero(summary: summary),
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'Order Summary',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'Order No', value: summary.entryNo),
                      _InfoRow(label: 'Date', value: summary.entryDate),
                      _InfoRow(label: 'Party Name', value: summary.partyName),
                      _InfoRow(
                        label: 'Party Mobile',
                        value: summary.partyMobile,
                      ),
                      _InfoRow(
                        label: 'Total Quantity',
                        value: summary.totalQty.toString(),
                      ),
                      _InfoRow(label: 'UUID', value: summary.uuid),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'Items',
                  trailing: Text(
                    '${detail?.items.length ?? 0} line(s)',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (controller.errorMessage.value != null &&
                          detail == null) ...[
                        _DetailBanner(
                          icon: Icons.wifi_off_outlined,
                          message: controller.errorMessage.value!,
                          color: Colors.red.shade700,
                          backgroundColor: Colors.red.shade50,
                        ),
                      ] else if (controller.isLoading.value &&
                          detail == null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ] else if ((detail?.items ?? const <OrderItemModel>[])
                          .isEmpty) ...[
                        const _DetailEmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'No item lines',
                          subtitle:
                              'The remote API did not return item rows for this order.',
                        ),
                      ] else ...[
                        for (final item in detail!.items) ...[
                          _ItemTile(item: item),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.summary});

  final OrderSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order #${summary.entryNo.isEmpty ? '-' : summary.entryNo}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary.partyName.isEmpty ? 'No party name' : summary.partyName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroChip(
                icon: Icons.calendar_today_outlined,
                label: summary.entryDate.isEmpty
                    ? 'No date'
                    : summary.entryDate,
              ),
              _HeroChip(
                icon: Icons.phone_outlined,
                label: summary.partyMobile.isEmpty
                    ? 'No mobile'
                    : summary.partyMobile,
              ),
              _HeroChip(
                icon: Icons.shopping_bag_outlined,
                label: '${summary.totalQty} total qty',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.trim().isEmpty ? '-' : value.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              safeValue,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final OrderItemModel item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.itemName.isEmpty ? 'No item name' : item.itemName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ItemBadge(
                icon: Icons.qr_code_2_outlined,
                label: item.itemCode.isEmpty ? 'No code' : item.itemCode,
              ),
              _ItemBadge(
                icon: Icons.inventory_outlined,
                label: 'Qty ${item.quantity}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemBadge extends StatelessWidget {
  const _ItemBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBanner extends StatelessWidget {
  const _DetailBanner({
    required this.icon,
    required this.message,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final String message;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailEmptyState extends StatelessWidget {
  const _DetailEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFF1F1F1),
              child: Icon(icon, color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
