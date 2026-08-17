import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/repair_service.dart';
import '../../data/models/repair_models.dart';

class RepairListController extends GetxController with GetSingleTickerProviderStateMixin {
  final RepairService _repairService = Get.find<RepairService>();

  late TabController tabController;

  // Observable Lists for both tabs
  final repairs = <RepairSummaryModel>[].obs;
  final karigarRepairs = <RepairSummaryModel>[].obs;

  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final karigarHasMore = true.obs;

  final page = 1.obs;
  final karigarPage = 1.obs;

  // Filter Controllers
  final entryNoController = TextEditingController();
  final partyNameController = TextEditingController();
  final partyMobileController = TextEditingController();
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();

  final filtersExpanded = false.obs;
  final selectedTabIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 2, vsync: this);

    // Listen for tab changes to refresh data
    tabController.addListener(() {
      // 2. Update the observable index whenever the tab changes
      selectedTabIndex.value = tabController.index;

      if (!tabController.indexIsChanging) {
        refreshRepairs();
      }
    });

    fetchRepairs(refresh: true);
  }

  bool get isKarigarTab => selectedTabIndex.value == 1;

  // --- THE MISSING GETTER ---
  bool get hasActiveFilters {
    return entryNoController.text.trim().isNotEmpty || partyNameController.text.trim().isNotEmpty || partyMobileController.text.trim().isNotEmpty || fromDate.value != null || toDate.value != null;
  }

  Future<void> fetchRepairs({bool refresh = false}) async {
    bool currentHasMore = isKarigarTab ? karigarHasMore.value : hasMore.value;
    if (!refresh && !currentHasMore) return;

    if (refresh) {
      if (isKarigarTab) {
        karigarPage.value = 1;
        karigarRepairs.clear();
      } else {
        page.value = 1;
        repairs.clear();
      }
    }

    isLoading.value = refresh;
    isLoadingMore.value = !refresh;

    try {
      final result = await _repairService.fetchRepairs(
        isKarigar: isKarigarTab,
        page: refresh ? 1 : (isKarigarTab ? karigarPage.value : page.value),
        pageSize: 20,
        entryNo: entryNoController.text.trim(),
        partyName: partyNameController.text.trim(),
        partyMobile: partyMobileController.text.trim(),
        dateFrom: _formatApiDate(fromDate.value),
        dateTo: _formatApiDate(toDate.value),
      );

      if (isKarigarTab) {
        karigarRepairs.addAll(result.repairs);
        karigarHasMore.value = result.hasMore;
        karigarPage.value++;
      } else {
        repairs.addAll(result.repairs);
        hasMore.value = result.hasMore;
        page.value++;
      }
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> refreshRepairs() => fetchRepairs(refresh: true);

  void toggleFilters() => filtersExpanded.toggle();

  void clearFilters() {
    entryNoController.clear();
    partyNameController.clear();
    partyMobileController.clear();
    fromDate.value = null;
    toDate.value = null;
    refreshRepairs();
  }

  String formatDisplayDate(DateTime? value) {
    if (value == null) return 'Select';
    return "${value.day}/${value.month}/${value.year}";
  }

  String _formatApiDate(DateTime? value) {
    if (value == null) return "";
    return "${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}";
  }

  @override
  void onClose() {
    tabController.dispose();
    entryNoController.dispose();
    partyNameController.dispose();
    partyMobileController.dispose();
    super.onClose();
  }
}
