import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/repair_service.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/repair_models.dart';

class RepairListController extends GetxController {
  final RepairService _repairService = Get.find<RepairService>();

  final entryNoController = TextEditingController();
  final partyNameController = TextEditingController();
  final partyMobileController = TextEditingController();

  final repairs = <RepairSummaryModel>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final page = 1.obs;
  final totalCount = 0.obs;
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();
  final errorMessage = RxnString();
  final filtersExpanded = false.obs;
  final filtersVersion = 0.obs;

  static const int pageSize = 20;
  late final Worker _fromDateWatcher;
  late final Worker _toDateWatcher;

  @override
  void onInit() {
    super.onInit();
    entryNoController.addListener(_markFiltersDirty);
    partyNameController.addListener(_markFiltersDirty);
    partyMobileController.addListener(_markFiltersDirty);
    _fromDateWatcher = ever<DateTime?>(fromDate, (_) => _markFiltersDirty());
    _toDateWatcher = ever<DateTime?>(toDate, (_) => _markFiltersDirty());
    fetchRepairs(refresh: true);
  }

  @override
  void onClose() {
    _fromDateWatcher.dispose();
    _toDateWatcher.dispose();
    entryNoController.dispose();
    partyNameController.dispose();
    partyMobileController.dispose();
    super.onClose();
  }

  Future<void> fetchRepairs({bool refresh = false}) async {
    if (refresh) {
      page.value = 1;
      hasMore.value = true;
      repairs.clear();
    }
    if (!hasMore.value && !refresh) return;

    if (refresh || page.value == 1) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      errorMessage.value = null;
      final result = await _repairService.fetchRepairs(
        page: refresh ? 1 : page.value,
        pageSize: pageSize,
        entryNo: entryNoController.text.trim(),
        partyName: partyNameController.text.trim(),
        partyMobile: partyMobileController.text.trim(),
        dateFrom: _formatApiDate(fromDate.value),
        dateTo: _formatApiDate(toDate.value),
      );
      totalCount.value = result.totalCount;
      hasMore.value = result.hasMore;
      if (refresh) {
        repairs.assignAll(result.repairs);
        page.value = 2;
      } else {
        repairs.addAll(result.repairs);
        page.value++;
      }
    } catch (error) {
      errorMessage.value = _friendlyRepairMessage(error);
      ApiResponseHandler.showErrorSnackbar('Could not load repairs');
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
    fetchRepairs(refresh: true);
  }

  int get activeFilterCount {
    var count = 0;
    if (entryNoController.text.trim().isNotEmpty) count++;
    if (partyNameController.text.trim().isNotEmpty) count++;
    if (partyMobileController.text.trim().isNotEmpty) count++;
    if (fromDate.value != null) count++;
    if (toDate.value != null) count++;
    return count;
  }

  bool get hasActiveFilters => activeFilterCount > 0;

  String formatDisplayDate(DateTime? value) {
    if (value == null) return 'Select';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  void _markFiltersDirty() {
    filtersVersion.value++;
  }

  String _formatApiDate(DateTime? value) {
    if (value == null) return '';
    return '${value.year}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _friendlyRepairMessage(Object error) {
    final text = error.toString().trim();
    if (text.isEmpty) {
      return 'Repairs are unavailable right now. Please try again.';
    }
    final lower = text.toLowerCase();
    if (lower.contains('socket') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection') ||
        lower.contains('timeout')) {
      return 'Repairs are unavailable right now. Please check your connection and try again.';
    }
    if (lower.contains('record not found')) {
      return 'No repairs found.';
    }
    if (lower.contains('exception') ||
        lower.contains('sql') ||
        lower.contains('syntax') ||
        lower.contains('trace')) {
      return 'Repairs are unavailable right now. Please try again shortly.';
    }
    return text;
  }
}
