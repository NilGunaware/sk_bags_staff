import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/order_models.dart';
import '../../routes/app_routes.dart';
import 'order_list_controller.dart';

class OrderListView extends GetView<OrderListController> {
  const OrderListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            onPressed: () async {
              final created = await Get.toNamed(Routes.orderCreate);
              if (created == true) {
                await controller.refreshOrders();
              }
            },
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Create order',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await Get.toNamed(Routes.orderCreate);
          if (created == true) {
            await controller.refreshOrders();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
      ),
      body: SafeArea(
        child: Obx(() {
          final orders = controller.orders;
          final isInitialLoading = controller.isLoading.value && orders.isEmpty;

          return RefreshIndicator(
            onRefresh: controller.refreshOrders,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(
                        title: 'Order Filters',
                        subtitle:
                            'Search remote order data from interlinkpos.com.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller.entryNoController,
                        decoration: const InputDecoration(
                          labelText: 'Entry No',
                          hintText: 'Enter order no',
                          prefixIcon: Icon(Icons.tag_outlined),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller.partyNameController,
                        decoration: const InputDecoration(
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
                        decoration: const InputDecoration(
                          labelText: 'Party Mobile',
                          hintText: 'Search by mobile no',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              label: 'From Date',
                              value: controller.fromDate.value,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      controller.fromDate.value ??
                                      DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  controller.fromDate.value = picked;
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DateField(
                              label: 'To Date',
                              value: controller.toDate.value,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      controller.toDate.value ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  controller.toDate.value = picked;
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  controller.fetchOrders(refresh: true),
                              icon: const Icon(Icons.search),
                              label: const Text('Apply'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: controller.clearFilters,
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Reset'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: 'Order List',
                        subtitle:
                            '${controller.totalCount.value} order(s) from the remote API.',
                        trailing: IconButton(
                          onPressed: controller.refreshOrders,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Reload',
                        ),
                      ),
                      if (controller.errorMessage.value != null &&
                          orders.isEmpty) ...[
                        const SizedBox(height: 8),
                        _InlineMessage(
                          icon: Icons.error_outline,
                          message: controller.errorMessage.value!,
                          color: Colors.red.shade700,
                          backgroundColor: Colors.red.shade50,
                        ),
                      ],
                      if (isInitialLoading) ...[
                        const SizedBox(height: 20),
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ] else if (orders.isEmpty) ...[
                        const SizedBox(height: 20),
                        const _EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No orders found',
                          subtitle:
                              'Try a different filter or create a fresh order.',
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        for (final order in orders) ...[
                          _OrderCard(
                            order: order,
                            onTap: () => Get.toNamed(
                              Routes.orderDetail,
                              arguments: order,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                            padding: const EdgeInsets.only(top: 4),
                            child: OutlinedButton.icon(
                              onPressed: controller.fetchOrders,
                              icon: const Icon(Icons.expand_more),
                              label: const Text('Load More'),
                            ),
                          ),
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final OrderSummaryModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F8F8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Order #${order.entryNo.isEmpty ? '-' : order.entryNo}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(
                    icon: Icons.calendar_today_outlined,
                    label: order.entryDate.isEmpty
                        ? 'No date'
                        : order.entryDate,
                  ),
                  _MetaChip(
                    icon: Icons.shopping_bag_outlined,
                    label: '${order.totalQty} item qty',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                order.partyName.isEmpty ? 'No party name' : order.partyName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (order.partyMobile.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  order.partyMobile,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
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
          ),
        ),
        if (trailing != null) trailing!,
      ],
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFFF1F1F1),
          child: Icon(icon, color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
