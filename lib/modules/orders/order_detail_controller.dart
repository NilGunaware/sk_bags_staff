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
      errorMessage.value = error.toString();
      ApiResponseHandler.showErrorSnackbar('Could not load order details');
    } finally {
      isLoading.value = false;
    }
  }
}
