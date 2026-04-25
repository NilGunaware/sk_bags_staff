import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/order_models.dart';
import '../../routes/app_routes.dart';
import 'order_list_controller.dart';

class OrderListView extends GetView<OrderListController> {
  const OrderListView({super.key});

  Future<void> _openCreateOrder() async {
    final result = await Get.toNamed(Routes.orderCreate);
    final created =
        result == true || (result is Map && result['created'] == true);

    if (created) {
      await controller.refreshOrders();
      final message = result is Map
          ? (result['message'] ?? 'Order created successfully').toString()
          : 'Order created successfully';
      ApiResponseHandler.showSuccessSnackbar(message);
    }
  }

  Future<void> _pickFromDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.fromDate.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      controller.fromDate.value = picked;
    }
  }

  Future<void> _pickToDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.toDate.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      controller.toDate.value = picked;
    }
  }

  Widget _buildFilterPanel(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSingleColumn = constraints.maxWidth < 560;

        final dateFields = useSingleColumn
            ? Column(
                children: [
                  _DateField(
                    label: 'From Date',
                    value: controller.fromDate.value,
                    onTap: () => _pickFromDate(context),
                  ),
                  const SizedBox(height: 12),
                  _DateField(
                    label: 'To Date',
                    value: controller.toDate.value,
                    onTap: () => _pickToDate(context),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'From Date',
                      value: controller.fromDate.value,
                      onTap: () => _pickFromDate(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'To Date',
                      value: controller.toDate.value,
                      onTap: () => _pickToDate(context),
                    ),
                  ),
                ],
              );

        final actions = useSingleColumn
            ? Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => controller.fetchOrders(refresh: true),
                      icon: const Icon(Icons.search),
                      label: const Text('Apply Filters'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: controller.clearFilters,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Clear Filters'),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => controller.fetchOrders(refresh: true),
                      icon: const Icon(Icons.search),
                      label: const Text('Apply Filters'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.clearFilters,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Clear Filters'),
                    ),
                  ),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller.entryNoController,
              decoration: _buildFilterDecoration(
                labelText: 'Entry No',
                hintText: 'Enter order no',
                prefixIcon: Icon(Icons.tag_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.partyNameController,
              decoration: _buildFilterDecoration(
                labelText: 'Party Name',
                hintText: 'Search by party',
                prefixIcon: Icon(Icons.person_search_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.partyMobileController,
              keyboardType: TextInputType.phone,
              decoration: _buildFilterDecoration(
                labelText: 'Party Mobile',
                hintText: 'Search by mobile no',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            dateFields,
            const SizedBox(height: 16),
            actions,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          Obx(
            () => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: controller.toggleFilters,
                    icon: Icon(
                      controller.filtersExpanded.value
                          ? Icons.filter_alt_off_outlined
                          : Icons.filter_alt_outlined,
                    ),
                    tooltip: controller.filtersExpanded.value
                        ? 'Hide filters'
                        : 'Show filters',
                  ),
                  if (controller.hasActiveFilters)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDA3F57),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: _openCreateOrder,
        icon: const Icon(Icons.add),
        label: const Text('Create Order'),
      ),
      body: SafeArea(
        child: Obx(() {
          controller.filtersVersion.value;
          final orders = controller.orders;
          final isInitialLoading = controller.isLoading.value && orders.isEmpty;

          return RefreshIndicator(
            onRefresh: controller.refreshOrders,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: controller.filtersExpanded.value
                      ? Padding(
                          key: const ValueKey('filters-open'),
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionHeader(
                                  title: 'Filter Orders',
                                  subtitle: controller.hasActiveFilters
                                      ? '${controller.activeFilterCount} filter(s) applied for ${controller.totalCount.value} order(s).'
                                      : 'Filter remote orders from interlinkpos.com.',
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _StatusBadge(
                                      icon: Icons.filter_alt_outlined,
                                      label: controller.hasActiveFilters
                                          ? '${controller.activeFilterCount} active'
                                          : 'All orders',
                                      isHighlighted:
                                          controller.hasActiveFilters,
                                    ),
                                    _StatusBadge(
                                      icon: Icons.search_outlined,
                                      label: 'Tap apply to refresh',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildFilterPanel(context),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('filters-closed')),
                ),

                if (controller.errorMessage.value != null &&
                    orders.isEmpty) ...[
                  _InlineMessage(
                    icon: Icons.error_outline,
                    message: controller.errorMessage.value!,
                    color: Colors.red.shade700,
                    backgroundColor: Colors.red.shade50,
                  ),
                  const SizedBox(height: 16),
                ],
                if (isInitialLoading)
                  const _StateCard(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                else if (orders.isEmpty)
                  _StateCard(
                    child: _EmptyOrdersPanel(
                      hasActiveFilters: controller.hasActiveFilters,
                      onPrimaryAction: controller.hasActiveFilters
                          ? controller.clearFilters
                          : _openCreateOrder,
                    ),
                  )
                else ...[
                  _OrdersSummaryCard(
                    title: 'Order List',
                    subtitle: controller.hasActiveFilters
                        ? '${controller.totalCount.value} order(s) matching your filters from interlinkpos.com.'
                        : '${controller.totalCount.value} order(s) from interlinkpos.com.',
                  ),
                  if (controller.errorMessage.value != null) ...[
                    const SizedBox(height: 10),
                    _InlineMessage(
                      icon: Icons.error_outline,
                      message: controller.errorMessage.value!,
                      color: Colors.red.shade700,
                      backgroundColor: Colors.red.shade50,
                    ),
                  ],
                  const SizedBox(height: 12),
                  ...[
                    for (final order in orders) ...[
                      _OrderCard(
                        order: order,
                        onTap: () =>
                            Get.toNamed(Routes.orderDetail, arguments: order),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (controller.isLoadingMore.value)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    if (controller.hasMore.value &&
                        !controller.isLoadingMore.value)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: OutlinedButton.icon(
                          onPressed: controller.fetchOrders,
                          icon: const Icon(Icons.expand_more),
                          label: const Text('Load More'),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

InputDecoration _buildFilterDecoration({
  required String labelText,
  required String hintText,
  required Widget prefixIcon,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: const Color(0xFFF8F8F8),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(Colors.black12),
    enabledBorder: border(Colors.black12),
    focusedBorder: border(AppColors.primary, 1.2),
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final OrderSummaryModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.entryNo.isEmpty ? '-' : order.entryNo}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.partyName.isEmpty
                                ? 'No party name'
                                : order.partyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CompactQtyBadge(quantity: order.totalQty),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _CompactMetaChip(
                        icon: Icons.calendar_today_outlined,
                        label: order.entryDate.isEmpty
                            ? 'No date'
                            : order.entryDate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (order.partyMobile.isNotEmpty)
                      Expanded(
                        child: _CompactMetaChip(
                          icon: Icons.phone_outlined,
                          label: order.partyMobile,
                        ),
                      )
                    else
                      const Expanded(
                        child: _CompactMetaChip(
                          icon: Icons.info_outline,
                          label: 'No mobile',
                        ),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Select'
        : '${value!.day.toString().padLeft(2, '0')}/'
              '${value!.month.toString().padLeft(2, '0')}/'
              '${value!.year}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.date_range_outlined),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: value == null ? Colors.grey.shade600 : AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _OrdersSummaryCard extends StatelessWidget {
  const _OrdersSummaryCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactQtyBadge extends StatelessWidget {
  const _CompactQtyBadge({required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            size: 15,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '$quantity qty',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMetaChip extends StatelessWidget {
  const _CompactMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, height: 1.3),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    this.isHighlighted = false,
  });

  final IconData icon;
  final String label;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isHighlighted
        ? AppColors.primary.withValues(alpha: 0.08)
        : const Color(0xFFF6F6F6);
    final borderColor = isHighlighted
        ? AppColors.primary.withValues(alpha: 0.16)
        : Colors.black12;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
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

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
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

class _EmptyOrdersPanel extends StatelessWidget {
  const _EmptyOrdersPanel({
    required this.hasActiveFilters,
    required this.onPrimaryAction,
  });

  final bool hasActiveFilters;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            color: AppColors.primary,
            size: 30,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          hasActiveFilters ? 'No matching orders' : 'No orders found',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hasActiveFilters
              ? 'Try clearing a few filters to see more results.'
              : 'Create your first order to start seeing order history here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, height: 1.35),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPrimaryAction,
            icon: Icon(
              hasActiveFilters ? Icons.restart_alt : Icons.add_circle_outline,
            ),
            label: Text(hasActiveFilters ? 'Clear Filters' : 'Create Order'),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'You can also pull down to refresh the latest data.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
