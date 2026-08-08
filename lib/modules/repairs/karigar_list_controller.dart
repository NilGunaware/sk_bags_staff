import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/repair_service.dart';
import '../../../core/utils/api_response_handler.dart';
import '../../../data/models/karigar_model.dart';

class KarigarListController extends GetxController {
  final RepairService _repairService = Get.find<RepairService>();

  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final passwordController = TextEditingController();
  final addressController = TextEditingController();
  final shopNameController = TextEditingController();
  final searchController = TextEditingController();

  final karigars = <KarigarModel>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final editingKarigarId = RxnString();

  bool get isEditMode => editingKarigarId.value != null;

  @override
  void onInit() {
    super.onInit();
    fetchKarigars();
  }

  @override
  void onClose() {
    nameController.dispose();
    mobileController.dispose();
    passwordController.dispose();
    addressController.dispose();
    shopNameController.dispose();
    searchController.dispose();
    super.onClose();
  }

  Future<void> fetchKarigars() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final list = await _repairService.fetchKarigars(
        name: searchController.text.trim(),
      );
      karigars.assignAll(list);
      if (karigars.isEmpty) {
        errorMessage.value = 'No karigars found.';
      }
    } catch (error) {
      errorMessage.value = error.toString();
      ApiResponseHandler.showErrorSnackbar('Could not load karigars');
    } finally {
      isLoading.value = false;
    }
  }

  void clearForm() {
    nameController.clear();
    mobileController.clear();
    passwordController.clear();
    addressController.clear();
    shopNameController.clear();
    editingKarigarId.value = null;
  }

  void setEditingKarigar(KarigarModel karigar) {
    editingKarigarId.value = karigar.id;
    nameController.text = karigar.name;
    mobileController.text = karigar.mobileNo;
    addressController.text = karigar.address;
    shopNameController.text = karigar.shopName;
    passwordController.clear();
  }

  Future<void> saveKarigar() async {
    final name = nameController.text.trim();
    final mobile = mobileController.text.trim();
    final password = passwordController.text.trim();
    final address = addressController.text.trim();
    final shopName = shopNameController.text.trim();

    if (name.isEmpty || mobile.isEmpty || (password.isEmpty && !isEditMode)) {
      ApiResponseHandler.showErrorSnackbar('Please fill all required fields');
      return;
    }

    isSaving.value = true;
    try {
      await _repairService.saveKarigar(
        id: editingKarigarId.value ?? '0',
        name: name,
        mobileNo: mobile,
        password: password,
        address: address,
        shopName: shopName,
      );
      ApiResponseHandler.showSuccessSnackbar(
        isEditMode ? 'Karigar updated successfully' : 'Karigar added successfully',
      );
      clearForm();
      Get.back(); // close dialog/sheet
      fetchKarigars();
    } catch (error) {
      ApiResponseHandler.showErrorSnackbar(error.toString());
    } finally {
      isSaving.value = false;
    }
  }
}
