import 'package:get/get.dart';

import '../../core/services/order_service.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/order_models.dart';

class OrderDetailController extends GetxController {
  final OrderService _orderService = Get.find<OrderService>();

  final order = Rxn<OrderSummaryModel>();
  final detail = Rxn<OrderDetailModel>();
  final isLoading = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    final argument = Get.arguments;
    if (argument is OrderSummaryModel) {
      order.value = argument;
      fetchDetail();
    }
  }

  Future<void> fetchDetail() async {
    final currentOrder = order.value;
    if (currentOrder == null || currentOrder.id.isEmpty) {
      return;
    }

    isLoading.value = true;
    try {
      errorMessage.value = null;
      detail.value = await _orderService.fetchOrderDetail(currentOrder.id);
    } catch (error) {
      errorMessage.value = _friendlyOrderDetailMessage(error);
      ApiResponseHandler.showErrorSnackbar('Could not load order details');
    } finally {
      isLoading.value = false;
    }
  }

  String _friendlyOrderDetailMessage(Object error) {
    final text = error.toString().trim();
    if (text.isEmpty) {
      return 'Order details are unavailable right now. Please try again.';
    }

    final lower = text.toLowerCase();
    if (lower.contains('socket') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection') ||
        lower.contains('timeout')) {
      return 'Order details are unavailable right now. Please check your connection and try again.';
    }

    if (lower.contains('invalid response') ||
        lower.contains('unexpected character') ||
        lower.contains('formatexception')) {
      return 'The order service returned an invalid response. Please try again shortly.';
    }

    if (lower.contains('exception') ||
        lower.contains('sql') ||
        lower.contains('syntax') ||
        lower.contains('trace') ||
        lower.contains('stack')) {
      return 'Order details are unavailable right now. Please try again shortly.';
    }

    return text;
  }
}
