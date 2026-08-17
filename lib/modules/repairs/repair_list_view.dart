import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/repair_models.dart';
import '../../routes/app_routes.dart';
import 'repair_list_controller.dart';

class RepairListView extends GetView<RepairListController> {
  const RepairListView({super.key});

  // Helper method to show the date picker
  Future<void> _pickDate(BuildContext context, Rxn<DateTime> target) async {
    final picked = await showDatePicker(context: context, initialDate: target.value ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null) target.value = picked;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text('Repairs'),
        // TabBar added for the two categories
        bottom: TabBar(
          controller: controller.tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Repairing'),
            Tab(text: 'Karigar Repairing'),
          ],
        ),
        actions: [
          IconButton(onPressed: () => Get.toNamed(Routes.karigars), icon: const Icon(Icons.people_outline), tooltip: 'Manage Karigars'),
          Obx(() => IconButton(onPressed: controller.toggleFilters, icon: Icon(controller.filtersExpanded.value ? Icons.filter_alt_off_outlined : Icons.filter_alt_outlined))),
        ],
      ),
      floatingActionButton: Obx(() {
        // Hide if the selected tab index is 1 (Karigar Repairing)
        if (controller.selectedTabIndex.value == 1) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton.extended(onPressed: () => Get.toNamed(Routes.repairCreate), icon: const Icon(Icons.add), label: const Text('Add Repair'));
      }),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Panel integrated with Obx and required arguments
            Obx(
              () => controller.filtersExpanded.value
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: _FilterPanel(controller: controller, onFromDate: () => _pickDate(context, controller.fromDate), onToDate: () => _pickDate(context, controller.toDate)),
                    )
                  : const SizedBox.shrink(),
            ),

            // TabBarView for the two lists
            Expanded(
              child: TabBarView(controller: controller.tabController, children: const [_RepairListTab(isKarigar: false), _RepairListTab(isKarigar: true)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepairListTab extends GetView<RepairListController> {
  final bool isKarigar;
  const _RepairListTab({required this.isKarigar});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Choose the list based on the tab
      final repairs = isKarigar ? controller.karigarRepairs : controller.repairs;
      final initialLoading = controller.isLoading.value && repairs.isEmpty;

      if (initialLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      if (repairs.isEmpty) {
        return _EmptyState(hasFilters: controller.hasActiveFilters, onPrimary: controller.hasActiveFilters ? controller.clearFilters : () => Get.toNamed(Routes.repairCreate));
      }

      return RefreshIndicator(
        onRefresh: controller.refreshRepairs,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          itemCount: repairs.length + (controller.isLoadingMore.value ? 1 : 0),
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == repairs.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final repair = repairs[index];
            return _RepairCard(
              repair: repair,
              onTap: () => Get.toNamed(Routes.repairDetail, arguments: {'repair': repair, 'isKarigar': isKarigar}),
            );
          },
        ),
      );
    });
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({required this.controller, required this.onFromDate, required this.onToDate});

  final RepairListController controller;
  final VoidCallback onFromDate;
  final VoidCallback onToDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SummaryHeader(title: 'Filter List', subtitle: 'Search by entry, party, or date range.'),
        const SizedBox(height: 14),
        TextField(controller: controller.entryNoController, decoration: _inputDecoration('Entry No', Icons.tag_outlined), textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        TextField(controller: controller.partyNameController, decoration: _inputDecoration('Party Name', Icons.person_outline), textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        TextField(controller: controller.partyMobileController, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _inputDecoration('Party Mobile', Icons.phone_outlined)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DateButton(label: 'From', value: controller.formatDisplayDate(controller.fromDate.value), onTap: onFromDate),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DateButton(label: 'To', value: controller.formatDisplayDate(controller.toDate.value), onTap: onToDate),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(onPressed: () => controller.fetchRepairs(refresh: true), icon: const Icon(Icons.search), label: const Text('Apply')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(onPressed: controller.clearFilters, icon: const Icon(Icons.restart_alt), label: const Text('Clear')),
            ),
          ],
        ),
      ],
    );
  }
}

// --- HELPER WIDGETS ---

class _RepairCard extends StatelessWidget {
  const _RepairCard({required this.repair, required this.onTap});
  final RepairSummaryModel repair;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.home_repair_service_outlined, color: Color(0xFF2563EB)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Repair #${repair.entryNo}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Text(repair.entryDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              Text(repair.partyName, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(repair.partyMobile, style: const TextStyle(color: Colors.grey)),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.home_repair_service_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(hasFilters ? 'No repair found matching filters' : 'No repairs yet'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onPrimary, child: Text(hasFilters ? 'Clear Filters' : 'Add Repair')),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_outlined, size: 16),
      label: Text('$label: $value', style: const TextStyle(fontSize: 12)),
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
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

InputDecoration _inputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}
