import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/order_models.dart';
import '../../routes/app_routes.dart';
import '../home/fallback_network_image.dart';
import 'order_detail_controller.dart';

class OrderDetailView extends GetView<OrderDetailController> {
  const OrderDetailView({super.key});

  Future<void> _openUpdateOrder() async {
    final detail = controller.detail.value;
    if (detail == null || controller.isLoading.value) {
      return;
    }

    final result = await Get.toNamed(Routes.orderCreate, arguments: detail);
    final updated =
        result == true || (result is Map && result['updated'] == true);
    if (!updated) {
      return;
    }

    controller.wasUpdated = true;
    await controller.fetchDetail();
    final message = result is Map
        ? (result['message'] ?? 'Order updated successfully').toString()
        : 'Order updated successfully';
    ApiResponseHandler.showSuccessSnackbar(message);
  }

  void _goBack() {
    Get.back<Map<String, dynamic>?>(
      result: controller.wasUpdated ? <String, dynamic>{'updated': true} : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Map<String, dynamic>?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _goBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F4),
        appBar: AppBar(
          leading: BackButton(onPressed: _goBack),
          title: const Text('Order Details'),
          actions: [
            Obx(() {
              final canEdit =
                  controller.detail.value != null &&
                  !controller.isLoading.value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: canEdit ? _openUpdateOrder : null,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white54,
                  ),
                ),
              );
            }),
          ],
        ),
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

            final items = detail?.items ?? const <OrderItemModel>[];

            return RefreshIndicator(
              onRefresh: controller.fetchDetail,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _OrderHeader(summary: summary, itemCount: items.length),
                  const SizedBox(height: 14),
                  _StatsRow(summary: summary, itemCount: items.length),
                  const SizedBox(height: 14),
                  _InformationCard(summary: summary),
                  const SizedBox(height: 14),
                  if (controller.isHydratingItems.value) ...[
                    const _InlineBanner(
                      icon: Icons.image_search_outlined,
                      message:
                          'Loading item images, prices, and live details...',
                      color: AppColors.primary,
                      backgroundColor: Color(0xFFEFF3FF),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (controller.itemDetailWarnings.isNotEmpty) ...[
                    for (final warning in controller.itemDetailWarnings) ...[
                      _InlineBanner(
                        icon: Icons.info_outline,
                        message: warning,
                        color: Colors.orange.shade800,
                        backgroundColor: Colors.orange.shade50,
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 6),
                  ],
                  if (controller.errorMessage.value != null &&
                      detail == null) ...[
                    _InlineBanner(
                      icon: Icons.wifi_off_outlined,
                      message: controller.errorMessage.value!,
                      color: Colors.red.shade700,
                      backgroundColor: Colors.red.shade50,
                    ),
                    const SizedBox(height: 14),
                  ],
                  _ItemsCard(
                    items: items,
                    isLoading: controller.isLoading.value && detail == null,
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.summary, required this.itemCount});

  final OrderSummaryModel summary;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${_dash(summary.entryNo)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _dash(summary.partyName),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeaderChip(
                icon: Icons.calendar_today_outlined,
                label: _dash(summary.entryDate),
              ),
              _HeaderChip(
                icon: Icons.phone_outlined,
                label: _dash(summary.partyMobile),
              ),
              _HeaderChip(
                icon: Icons.inventory_2_outlined,
                label: '$itemCount line(s)',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.summary, required this.itemCount});

  final OrderSummaryModel summary;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Items',
            value: itemCount.toString(),
            icon: Icons.list_alt_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Total Qty',
            value: summary.totalQty.toString(),
            icon: Icons.shopping_bag_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Status',
            value: 'Ready',
            icon: Icons.verified_outlined,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.summary});

  final OrderSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      title: 'Order Information',
      subtitle: 'Customer and order reference details',
      child: Column(
        children: [
          _InfoTile(
            icon: Icons.tag_outlined,
            label: 'Order No',
            value: _dash(summary.entryNo),
          ),
          _InfoTile(
            icon: Icons.calendar_month_outlined,
            label: 'Date',
            value: _dash(summary.entryDate),
          ),
          _InfoTile(
            icon: Icons.person_outline,
            label: 'Party Name',
            value: _dash(summary.partyName),
          ),
          _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Mobile No',
            value: _dash(summary.partyMobile),
          ),
          _InfoTile(
            icon: Icons.fingerprint_outlined,
            label: 'UUID',
            value: _dash(summary.uuid),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
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

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.items, required this.isLoading});

  final List<OrderItemModel> items;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      title: 'Item Lines',
      subtitle: '${items.length} item(s) in this order',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${items.fold<int>(0, (sum, item) => sum + item.quantity)} qty',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : items.isEmpty
          ? const _DetailEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No item lines',
              subtitle:
                  'The remote API did not return item rows for this order.',
            )
          : Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _ItemLineCard(index: index + 1, item: items[index]),
                  if (index != items.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _ItemLineCard extends StatelessWidget {
  const _ItemLineCard({required this.index, required this.item});

  final int index;
  final OrderItemModel item;

  @override
  Widget build(BuildContext context) {
    final detail = item.itemDetails;
    final prices = _visiblePrices(detail?.prices ?? const <ItemPriceModel>[]);
    final detailImageUrl = detail?.image?.url;
    final imageUrls = <String>[
      ...?detail?.imageUrls,
      if (detailImageUrl != null && detailImageUrl.isNotEmpty) detailImageUrl,
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 62,
                  height: 62,
                  color: AppColors.primary.withValues(alpha: 0.06),
                  child: FallbackNetworkImage(
                    imageUrls: imageUrls,
                    iconColor: AppColors.primary,
                    iconSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName.isEmpty ? 'No item name' : item.itemName,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SoftBadge(
                          icon: Icons.confirmation_number_outlined,
                          label: '#$index',
                        ),
                        _SoftBadge(
                          icon: Icons.qr_code_2_outlined,
                          label: _dash(item.itemCode),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _QtyPill(quantity: item.quantity),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SoftBadge(
                  icon: Icons.storefront_outlined,
                  label: 'Stock ${_formatNumber(detail.totalQuantity)}',
                ),
                if (detail.itemGroup.trim().isNotEmpty)
                  _SoftBadge(
                    icon: Icons.category_outlined,
                    label: detail.itemGroup,
                  ),
              ],
            ),
          ],
          if (prices.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final price in prices) ...[
                    _PriceBadge(price: price),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QtyPill extends StatelessWidget {
  const _QtyPill({required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Qty',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            quantity.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.price});

  final ItemPriceModel price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            price.displayName,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatPrice(price.finalPrice),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
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
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
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
                fontWeight: FontWeight.w900,
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

List<ItemPriceModel> _visiblePrices(List<ItemPriceModel> prices) {
  final visible = prices
      .where((price) => price.isPrimaryBusinessPrice)
      .toList();
  final source = visible.isEmpty ? prices.take(4).toList() : visible;
  const order = <String>['A', 'W', 'C', 'H'];
  source.sort(
    (a, b) =>
        order.indexOf(a.displayCode).compareTo(order.indexOf(b.displayCode)),
  );
  return source.take(4).toList();
}

String _dash(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}

String _formatNumber(num value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

String _formatPrice(num value) => value.round().toString();
