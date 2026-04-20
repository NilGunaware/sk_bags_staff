import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/order_service.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/order_models.dart';

class OrderListController extends GetxController {
  final OrderService _orderService = Get.find<OrderService>();

  final entryNoController = TextEditingController();
  final partyNameController = TextEditingController();
  final partyMobileController = TextEditingController();

  final orders = <OrderSummaryModel>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final page = 1.obs;
  final totalCount = 0.obs;
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();
  final errorMessage = RxnString();

  static const int pageSize = 20;

  @override
  void onInit() {
    super.onInit();
    fetchOrders(refresh: true);
  }

  @override
  void onClose() {
    entryNoController.dispose();
    partyNameController.dispose();
    partyMobileController.dispose();
    super.onClose();
  }

  Future<void> fetchOrders({bool refresh = false}) async {
    if (refresh) {
      page.value = 1;
      hasMore.value = true;
      orders.clear();
    }

    if (!hasMore.value && !refresh) {
      return;
    }

    if (refresh || page.value == 1) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      errorMessage.value = null;
      final result = await _orderService.fetchOrders(
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
        orders.assignAll(result.orders);
        page.value = 2;
      } else {
        orders.addAll(result.orders);
        page.value++;
      }
    } catch (error) {
      errorMessage.value = error.toString();
      ApiResponseHandler.showErrorSnackbar('Could not load orders');
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> refreshOrders() => fetchOrders(refresh: true);

  void clearFilters() {
    entryNoController.clear();
    partyNameController.clear();
    partyMobileController.clear();
    fromDate.value = null;
    toDate.value = null;
    fetchOrders(refresh: true);
  }

  String formatDisplayDate(DateTime? value) {
    if (value == null) return 'Select';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String _formatApiDate(DateTime? value) {
    if (value == null) return '';
    return '${value.year}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
