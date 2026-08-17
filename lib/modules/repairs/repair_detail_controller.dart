import 'package:get/get.dart';

import '../../core/services/repair_service.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/repair_models.dart';

class RepairDetailController extends GetxController {
  final RepairService _repairService = Get.find<RepairService>();

  final repair = Rxn<RepairSummaryModel>();
  final detail = Rxn<RepairDetailModel>();
  final isLoading = false.obs;
  final errorMessage = RxnString();

  // Flag to check if data is from Karigar tab
  final isKarigar = false.obs;
  bool wasUpdated = false;

  @override
  void onInit() {
    super.onInit();
    final argument = Get.arguments;

    if (argument is Map) {
      // Data coming from the new Tab system
      repair.value = argument['repair'];
      isKarigar.value = argument['isKarigar'] ?? false;
      fetchDetail();
    } else if (argument is RepairSummaryModel) {
      // Fallback for direct navigation
      repair.value = argument;
      fetchDetail();
    } else if (argument is RepairDetailModel) {
      detail.value = argument;
      repair.value = argument.summary;
      fetchDetail();
    }
  }

  Future<void> fetchDetail() async {
    final currentRepair = repair.value;
    if (currentRepair == null || currentRepair.id.isEmpty) return;

    isLoading.value = true;
    try {
      errorMessage.value = null;
      // Pass the isKarigar flag to the service to use the correct API
      detail.value = await _repairService.fetchRepairDetail(currentRepair.id, isKarigar: isKarigar.value);
    } catch (error) {
      errorMessage.value = _friendlyRepairMessage(error);
      ApiResponseHandler.showErrorSnackbar('Could not load repair details');
    } finally {
      isLoading.value = false;
    }
  }

  String _friendlyRepairMessage(Object error) {
    final text = error.toString().trim();
    if (text.isEmpty) return 'Repair details are unavailable right now.';
    final lower = text.toLowerCase();
    if (lower.contains('connection') || lower.contains('timeout')) {
      return 'Repair details are unavailable. Check your connection.';
    }
    if (lower.contains('not found')) return 'Repair not found.';
    return text;
  }
}
