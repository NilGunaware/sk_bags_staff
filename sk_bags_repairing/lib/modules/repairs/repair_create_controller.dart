import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/services/repair_service.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/repair_models.dart';

class RepairCreateController extends GetxController {
  final RepairService _repairService = Get.find<RepairService>();
  final ImagePicker _imagePicker = ImagePicker();

  final formKey = GlobalKey<FormState>();
  final partyNameController = TextEditingController();
  final partyMobileController = TextEditingController();
  final advanceController = TextEditingController(text: '0');
  final notesController = TextEditingController();

  final items = <RepairDraftItem>[].obs;
  final shops = <RepairShopModel>[].obs;
  final selectedShop = Rxn<RepairShopModel>();
  final isPreparing = false.obs;
  final isShopLoading = false.obs;
  final isSubmitting = false.obs;
  final nextEntryNo = 1.obs;
  final deliveryDate = Rxn<DateTime>();
  final formVersion = 0.obs;

  late final String repairUuid;
  bool isEditMode = false;
  String editingRepairId = '';
  String editingEntryDate = '';

  bool get isWorkshop => ApiEndpoints.isWorkshop;

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
        deliveryDate.value = DateTime.now();
      }
      if (isWorkshop) {
        await fetchShops();
      }
    } catch (_) {
      if (!isEditMode) {
        nextEntryNo.value = 1;
        deliveryDate.value = DateTime.now();
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

  Future<String?> captureAttachment() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      return image?.path;
    } catch (error, stackTrace) {
      _handleAttachmentPickerError(error, stackTrace);
      return null;
    }
  }

  Future<List<String>> pickGalleryAttachments() async {
    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 85);
      return images.map((image) => image.path).toList();
    } catch (error, stackTrace) {
      _handleAttachmentPickerError(error, stackTrace);
      return <String>[];
    }
  }

  void _handleAttachmentPickerError(Object error, StackTrace stackTrace) {
    debugPrint('Attachment picker error: $error\n$stackTrace');
    final isChannelError =
        error is PlatformException && error.code == 'channel-error';
    ApiResponseHandler.showErrorSnackbar(
      isChannelError
          ? 'Attachment picker is not available. Close and reopen the updated app.'
          : 'Could not open the attachment picker. Please try again.',
    );
  }

  Future<void> fetchShops({String query = ''}) async {
    if (!isWorkshop) return;
    isShopLoading.value = true;
    try {
      final result = await _repairService.fetchShops(name: query.trim());
      shops.assignAll(result);
      final selected = selectedShop.value;
      if (selected != null && !shops.any((shop) => shop.id == selected.id)) {
        shops.insert(0, selected);
      }
    } catch (_) {
      ApiResponseHandler.showErrorSnackbar('Could not load store list');
    } finally {
      isShopLoading.value = false;
    }
  }

  void selectShop(RepairShopModel shop) {
    selectedShop.value = shop;
    _markFormChanged();
  }

  Future<void> saveShop({
    RepairShopModel? existing,
    required String name,
    required String mobileNo,
    required String address,
  }) async {
    if (name.trim().isEmpty) {
      ApiResponseHandler.showErrorSnackbar('Store name is required');
      return;
    }
    isShopLoading.value = true;
    try {
      final shop = await _repairService.saveShop(
        id: existing?.id ?? '0',
        name: name,
        mobileNo: mobileNo,
        address: address,
      );
      if (shop.id.isNotEmpty) {
        selectedShop.value = shop;
        final index = shops.indexWhere((item) => item.id == shop.id);
        if (index >= 0) {
          shops[index] = shop;
        } else {
          shops.insert(0, shop);
        }
      }
      ApiResponseHandler.showSuccessSnackbar(
        existing == null
            ? 'Store added successfully'
            : 'Store updated successfully',
      );
    } catch (_) {
      ApiResponseHandler.showErrorSnackbar('Could not save store');
    } finally {
      isShopLoading.value = false;
    }
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
    if (isWorkshop && (selectedShop.value?.id.trim().isEmpty ?? true)) {
      ApiResponseHandler.showErrorSnackbar('Please select a store');
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
              deliveryDate: _formatApiDate(DateTime.now()),
              notes: notesController.text,
              shopId: selectedShop.value?.id ?? '',
              items: items.toList(),
            )
          : await _repairService.createRepair(
              uuid: repairUuid,
              entryNo: nextEntryNo.value,
              entryDate: entryDate,
              partyName: partyNameController.text,
              partyMobile: partyMobileController.text,
              advanceAmount: advanceAmount,
              deliveryDate: _formatApiDate(DateTime.now()),
              notes: notesController.text,
              shopId: selectedShop.value?.id ?? '',
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
    if (summary.shopId.isNotEmpty || summary.shopName.isNotEmpty) {
      selectedShop.value = RepairShopModel(
        id: summary.shopId,
        name: summary.shopName,
        mobileNo: '',
        address: '',
      );
    }
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
