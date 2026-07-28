import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/repair_models.dart';
import '../../routes/app_routes.dart';
import 'repair_list_controller.dart';

class RepairListView extends GetView<RepairListController> {
  const RepairListView({super.key});

  Future<void> _openCreateRepair() async {
    final result = await Get.toNamed(Routes.repairCreate);
    final created =
        result == true || (result is Map && result['created'] == true);
    if (created) {
      await controller.refreshRepairs();
      final message = result is Map
          ? (result['message'] ?? 'Repair created successfully').toString()
          : 'Repair created successfully';
      ApiResponseHandler.showSuccessSnackbar(message);
    }
  }

  Future<void> _pickDate(BuildContext context, Rxn<DateTime> target) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: target.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) target.value = picked;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text('Repairs'),
        actions: [
          Obx(
            () => IconButton(
              onPressed: controller.toggleFilters,
              icon: Icon(
                controller.filtersExpanded.value
                    ? Icons.filter_alt_off_outlined
                    : Icons.filter_alt_outlined,
              ),
              tooltip: 'Filter repairs',
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateRepair,
        icon: const Icon(Icons.add),
        label: const Text('Add Repair'),
      ),
      body: SafeArea(
        child: Obx(() {
          controller.filtersVersion.value;
          final repairs = controller.repairs;
          final initialLoading = controller.isLoading.value && repairs.isEmpty;

          return RefreshIndicator(
            onRefresh: controller.refreshRepairs,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                if (controller.filtersExpanded.value) ...[
                  _Panel(
                    child: _FilterPanel(
                      controller: controller,
                      onFromDate: () => _pickDate(context, controller.fromDate),
                      onToDate: () => _pickDate(context, controller.toDate),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (controller.errorMessage.value != null &&
                    repairs.isEmpty) ...[
                  _InlineMessage(message: controller.errorMessage.value!),
                  const SizedBox(height: 14),
                ],
                if (initialLoading)
                  const _Panel(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (repairs.isEmpty)
                  _Panel(
                    child: _EmptyState(
                      hasFilters: controller.hasActiveFilters,
                      onPrimary: controller.hasActiveFilters
                          ? controller.clearFilters
                          : _openCreateRepair,
                    ),
                  )
                else ...[
                  _SummaryHeader(
                    title: 'Repair List',
                    subtitle: controller.hasActiveFilters
                        ? '${controller.totalCount.value} repair(s) matching filters.'
                        : '${controller.totalCount.value} repair(s) found.',
                  ),
                  const SizedBox(height: 12),
                  for (final repair in repairs) ...[
                    _RepairCard(
                      repair: repair,
                      onTap: () async {
                        final result = await Get.toNamed(
                          Routes.repairDetail,
                          arguments: repair,
                        );
                        if (result is Map && result['updated'] == true) {
                          await controller.refreshRepairs();
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (controller.isLoadingMore.value)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (controller.hasMore.value &&
                      !controller.isLoadingMore.value)
                    OutlinedButton.icon(
                      onPressed: controller.fetchRepairs,
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Load More'),
                    ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.controller,
    required this.onFromDate,
    required this.onToDate,
  });

  final RepairListController controller;
  final VoidCallback onFromDate;
  final VoidCallback onToDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SummaryHeader(
          title: 'Filter Repairs',
          subtitle: 'Search by entry, party, mobile, or date range.',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller.entryNoController,
          decoration: _inputDecoration('Entry No', Icons.tag_outlined),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.partyNameController,
          decoration: _inputDecoration('Party Name', Icons.person_outline),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.partyMobileController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDecoration('Party Mobile', Icons.phone_outlined),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DateButton(
                label: 'From',
                value: controller.formatDisplayDate(controller.fromDate.value),
                onTap: onFromDate,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DateButton(
                label: 'To',
                value: controller.formatDisplayDate(controller.toDate.value),
                onTap: onToDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => controller.fetchRepairs(refresh: true),
                icon: const Icon(Icons.search),
                label: const Text('Apply'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.clearFilters,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Clear'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RepairCard extends StatelessWidget {
  const _RepairCard({required this.repair, required this.onTap});

  final RepairSummaryModel repair;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.home_repair_service_outlined,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Repair #${repair.entryNo.isEmpty ? '-' : repair.entryNo}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          repair.partyName.isEmpty
                              ? 'No party name'
                              : repair.partyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(
                    icon: Icons.inventory_2_outlined,
                    label: '${repair.totalQty} qty',
                  ),
                  _Chip(
                    icon: Icons.currency_rupee,
                    label: _money(repair.totalAmount),
                  ),
                  if (repair.deliveryDate.isNotEmpty)
                    _Chip(
                      icon: Icons.event_available_outlined,
                      label: repair.deliveryDate,
                    ),
                  if (repair.partyMobile.isNotEmpty)
                    _Chip(
                      icon: Icons.phone_outlined,
                      label: repair.partyMobile,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilters, required this.onPrimary});

  final bool hasFilters;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.home_repair_service_outlined, size: 46),
          const SizedBox(height: 12),
          Text(
            hasFilters ? 'No repair found' : 'No repairs yet',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onPrimary,
            icon: Icon(hasFilters ? Icons.restart_alt : Icons.add),
            label: Text(hasFilters ? 'Clear Filters' : 'Add Repair'),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text('$label: $value', overflow: TextOverflow.ellipsis),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: const Color(0xFFF8F8F8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
  );
}

String _money(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}
