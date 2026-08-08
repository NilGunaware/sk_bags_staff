import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/karigar_model.dart';
import 'karigar_list_controller.dart';

class KarigarListView extends GetView<KarigarListController> {
  const KarigarListView({super.key});

  void _openKarigarSheet({KarigarModel? karigar}) {
    if (karigar != null) {
      controller.setEditingKarigar(karigar);
    } else {
      controller.clearForm();
    }
    Get.bottomSheet<void>(
      SafeArea(
        child: Container(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(Get.context!).viewInsets.bottom + 18,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.isEditMode ? 'Edit Karigar' : 'Add New Karigar',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller.nameController,
                  decoration: _inputDecoration('Name *', Icons.person_outline),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller.mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDecoration('Mobile No *', Icons.phone_outlined),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller.passwordController,
                  decoration: _inputDecoration(
                    controller.isEditMode ? 'Password (Leave empty to keep current)' : 'Password *',
                    Icons.lock_outline,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller.shopNameController,
                  decoration: _inputDecoration('Shop Name', Icons.storefront_outlined),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller.addressController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _inputDecoration('Address', Icons.location_on_outlined),
                ),
                const SizedBox(height: 20),
                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: controller.isSaving.value
                          ? null
                          : controller.saveKarigar,
                      icon: controller.isSaving.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(controller.isEditMode ? 'Update Karigar' : 'Save Karigar'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 54),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text('Manage Karigars'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openKarigarSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Add Karigar'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: controller.searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.searchController.clear();
                      controller.fetchKarigars();
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onSubmitted: (_) => controller.fetchKarigars(),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value && controller.karigars.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.karigars.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          controller.errorMessage.value ?? 'No karigars found.',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: controller.fetchKarigars,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: controller.karigars.length,
                    itemBuilder: (context, index) {
                      final karigar = controller.karigars[index];
                      final karigarId = int.tryParse(karigar.id) ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.person, color: AppColors.primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    karigar.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (karigar.mobileNo.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          karigar.mobileNo,
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (karigar.shopName.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.storefront_outlined, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          karigar.shopName,
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (karigar.address.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            karigar.address,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (karigarId > 0) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                                onPressed: () => _openKarigarSheet(karigar: karigar),
                                tooltip: 'Edit Karigar',
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      counterText: "",
    );
  }
}
