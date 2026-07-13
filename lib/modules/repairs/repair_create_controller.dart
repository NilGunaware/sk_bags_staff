import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/repair_service.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/repair_models.dart';

class RepairCreateController extends GetxController {
  final RepairService _repairService = Get.find<RepairService>();

  final formKey = GlobalKey<FormState>();
  final partyNameController = TextEditingController();
  final partyMobileController = TextEditingController();
  final advanceController = TextEditingController(text: '0');
  final notesController = TextEditingController();

  final items = <RepairDraftItem>[].obs;
  final isPreparing = false.obs;
  final isSubmitting = false.obs;
  final nextEntryNo = 1.obs;
  final deliveryDate = Rxn<DateTime>();
  final formVersion = 0.obs;

  late final String repairUuid;
  bool isEditMode = false;
  String editingRepairId = '';
  String editingEntryDate = '';

  @override
  void onInit() {
    super.onInit();
    advanceController.addListener(_markFormChanged);
    final argument = Get.arguments;
    if (argument is RepairDetailModel) {
      _configureForEdit(argument);
    } else {
      repairUuid = DateTime.now().millisecondsSinceEpoch.toString();
    }
    prepare();
  }

  @override
  void onClose() {
    advanceController.removeListener(_markFormChanged);
    partyNameController.dispose();
    partyMobileController.dispose();
    advanceController.dispose();
    notesController.dispose();
    super.onClose();
  }

  Future<void> prepare() async {
    isPreparing.value = true;
    try {
      if (!isEditMode) {
        nextEntryNo.value = await _repairService.suggestNextEntryNo();
        deliveryDate.value = DateTime.now().add(const Duration(days: 7));
      }
    } catch (_) {
      if (!isEditMode) {
        nextEntryNo.value = 1;
        deliveryDate.value = DateTime.now().add(const Duration(days: 7));
      }
    } finally {
      isPreparing.value = false;
    }
  }

  int get totalQuantity =>
      items.fold<int>(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      items.fold<double>(0, (sum, item) => sum + item.amount);

  double get advanceAmount =>
      double.tryParse(advanceController.text.trim()) ?? 0;

  double get balanceAmount => totalAmount - advanceAmount;

  String get entryDate => isEditMode && editingEntryDate.trim().isNotEmpty
      ? editingEntryDate.trim()
      : _formatApiDate(DateTime.now());

  String get displayEntryDate =>
      isEditMode && editingEntryDate.trim().isNotEmpty
      ? editingEntryDate.trim()
      : _formatDisplayDate(DateTime.now());

  String get displayDeliveryDate => _formatDisplayDate(deliveryDate.value);

  String get screenTitle => isEditMode ? 'Update Repair' : 'Create Repair';

  String get submitLabel => isEditMode ? 'Update Repair' : 'Save Repair';

  String get submittingLabel => isEditMode ? 'Updating...' : 'Saving...';

  Future<List<String>> pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result == null) return <String>[];
    return result.paths.whereType<String>().toList();
  }

  void addItem(RepairDraftItem item) {
    items.add(item);
  }

  void updateItem(int index, RepairDraftItem item) {
    if (index < 0 || index >= items.length) return;
    items[index] = item;
  }

  void removeItem(int index) {
    if (index < 0 || index >= items.length) return;
    items.removeAt(index);
  }

  void _markFormChanged() {
    formVersion.value++;
  }

  Future<void> submit() async {
    if (isSubmitting.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (items.isEmpty) {
      ApiResponseHandler.showErrorSnackbar('Add at least one repair item');
      return;
    }

    isSubmitting.value = true;
    try {
      final response = isEditMode
          ? await _repairService.updateRepair(
              repairId: editingRepairId,
              uuid: repairUuid,
              entryNo: nextEntryNo.value,
              entryDate: entryDate,
              partyName: partyNameController.text,
              partyMobile: partyMobileController.text,
              advanceAmount: advanceAmount,
              deliveryDate: _formatApiDate(
                deliveryDate.value ?? DateTime.now(),
              ),
              notes: notesController.text,
              items: items.toList(),
            )
          : await _repairService.createRepair(
              uuid: repairUuid,
              entryNo: nextEntryNo.value,
              entryDate: entryDate,
              partyName: partyNameController.text,
              partyMobile: partyMobileController.text,
              advanceAmount: advanceAmount,
              deliveryDate: _formatApiDate(
                deliveryDate.value ?? DateTime.now(),
              ),
              notes: notesController.text,
              items: items.toList(),
            );

      if (_repairService.isSuccessResponse(response)) {
        final message = _repairService.extractMessage(response);
        Get.back(
          result: <String, dynamic>{
            if (isEditMode) 'updated': true else 'created': true,
            'message': message.isEmpty
                ? (isEditMode
                      ? 'Repair updated successfully'
                      : 'Repair created successfully')
                : message,
          },
        );
        return;
      }

      final message = _repairService.extractMessage(response);
      ApiResponseHandler.showErrorSnackbar(
        message.isEmpty
            ? (isEditMode
                  ? 'Could not update repair'
                  : 'Could not create repair')
            : message,
      );
    } catch (_) {
      ApiResponseHandler.showErrorSnackbar(
        isEditMode ? 'Could not update repair' : 'Could not create repair',
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  void _configureForEdit(RepairDetailModel detail) {
    final summary = detail.summary;
    isEditMode = true;
    editingRepairId = summary.id;
    editingEntryDate = summary.entryDate;
    repairUuid = summary.uuid.trim().isEmpty || summary.uuid.trim() == '0'
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : summary.uuid;
    nextEntryNo.value = int.tryParse(summary.entryNo) ?? 0;
    partyNameController.text = summary.partyName;
    partyMobileController.text = summary.partyMobile;
    advanceController.text = _amountString(summary.advanceAmount);
    notesController.text = summary.notes;
    deliveryDate.value = _parseApiDate(summary.deliveryDate);
    items.assignAll(
      detail.items.map(
        (item) => RepairDraftItem(
          id: item.id,
          itemName: item.itemName,
          quantity: item.quantity <= 0 ? 1 : item.quantity,
          rate: item.rate,
          instruction: item.instruction,
          attachmentPaths: const <String>[],
          existingAttachments: item.attachments,
        ),
      ),
    );
  }

  String _formatApiDate(DateTime value) {
    return '${value.year}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _formatDisplayDate(DateTime? value) {
    if (value == null) return 'Select';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  DateTime? _parseApiDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  String _amountString(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}
