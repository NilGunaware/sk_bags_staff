import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/repair_models.dart';
import 'repair_create_controller.dart';

class RepairCreateView extends GetView<RepairCreateController> {
  const RepairCreateView({super.key});

  Future<void> _pickDeliveryDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          controller.deliveryDate.value ??
          DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) controller.deliveryDate.value = picked;
  }

  Future<void> _openItemSheet({int? index}) async {
    final existing = index == null ? null : controller.items[index];
    final itemNameController = TextEditingController(
      text: existing?.itemName ?? '',
    );
    final qtyController = TextEditingController(
      text: (existing?.quantity ?? 1).toString(),
    );
    final rateController = TextEditingController(
      text: _amount(existing?.rate ?? 0),
    );
    final instructionController = TextEditingController(
      text: existing?.instruction ?? '',
    );
    final existingAttachments =
        (existing?.existingAttachments.toList() ?? <String>[]).obs;
    final attachments = (existing?.attachmentPaths.toList() ?? <String>[]).obs;

    try {
      await Get.bottomSheet<void>(
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
                    index == null ? 'Add Repair Item' : 'Edit Repair Item',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: itemNameController,
                    decoration: _inputDecoration(
                      'Item Name',
                      Icons.home_repair_service_outlined,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _inputDecoration(
                            'Qty',
                            Icons.inventory_2_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: rateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          decoration: _inputDecoration(
                            'Rate',
                            Icons.currency_rupee,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: instructionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: _inputDecoration(
                      'Instruction',
                      Icons.notes_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Obx(
                    () => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final url in existingAttachments)
                          InputChip(
                            avatar: const Icon(Icons.cloud_done, size: 16),
                            label: Text(
                              _attachmentLabel(url),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onDeleted: () => existingAttachments.remove(url),
                          ),
                        for (final path in attachments)
                          Chip(
                            avatar: const Icon(Icons.attach_file, size: 16),
                            label: Text(
                              path.split('/').last,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onDeleted: () => attachments.remove(path),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await controller.pickAttachments();
                      attachments.addAll(picked);
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Attach Photos'),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final name = itemNameController.text.trim();
                        final qty = int.tryParse(qtyController.text) ?? 0;
                        final rate = double.tryParse(rateController.text) ?? 0;
                        if (name.isEmpty || qty <= 0) {
                          return;
                        }
                        final item = RepairDraftItem(
                          id: existing?.id ?? '',
                          itemName: name,
                          quantity: qty,
                          rate: rate,
                          instruction: instructionController.text,
                          attachmentPaths: attachments.toList(),
                          existingAttachments: existingAttachments.toList(),
                        );
                        if (index == null) {
                          controller.addItem(item);
                        } else {
                          controller.updateItem(index, item);
                        }
                        Get.back<void>();
                      },
                      icon: const Icon(Icons.check),
                      label: Text(index == null ? 'Add Item' : 'Update Item'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        isScrollControlled: true,
      );
    } finally {
      itemNameController.dispose();
      qtyController.dispose();
      rateController.dispose();
      instructionController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(title: Text(controller.screenTitle)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Obx(
            () => ElevatedButton.icon(
              onPressed: controller.isSubmitting.value
                  ? null
                  : controller.submit,
              icon: controller.isSubmitting.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                controller.isSubmitting.value
                    ? controller.submittingLabel
                    : controller.submitLabel,
              ),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 54)),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          controller.formVersion.value;
          return Stack(
            children: [
              Form(
                key: controller.formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    _Panel(
                      child: Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              label: 'Entry No',
                              value: '#${controller.nextEntryNo.value}',
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              label: 'Entry Date',
                              value: controller.displayEntryDate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Party Details'),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: controller.partyNameController,
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'Party name is required'
                                : null,
                            decoration: _inputDecoration(
                              'Party Name',
                              Icons.person_outline,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: controller.partyMobileController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              final text = (value ?? '').trim();
                              if (text.length < 10) {
                                return 'Enter valid mobile no';
                              }
                              return null;
                            },
                            decoration: _inputDecoration(
                              'Mobile No',
                              Icons.phone_outlined,
                            ),
                          ),
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            onPressed: () => _pickDeliveryDate(context),
                            icon: const Icon(Icons.event_available_outlined),
                            label: Text(
                              'Delivery: ${controller.displayDeliveryDate}',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: _SectionTitle('Repair Items'),
                              ),
                              IconButton.filledTonal(
                                onPressed: () => _openItemSheet(),
                                icon: const Icon(Icons.add),
                                tooltip: 'Add item',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (controller.items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text('No repair item added yet.'),
                              ),
                            )
                          else
                            for (var i = 0; i < controller.items.length; i++)
                              _DraftRepairTile(
                                item: controller.items[i],
                                onEdit: () => _openItemSheet(index: i),
                                onDelete: () => controller.removeItem(i),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Panel(
                      child: Column(
                        children: [
                          TextField(
                            controller: controller.advanceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            decoration: _inputDecoration(
                              'Advance Amount',
                              Icons.currency_rupee,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: controller.notesController,
                            minLines: 2,
                            maxLines: 4,
                            decoration: _inputDecoration(
                              'Notes',
                              Icons.notes_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _Metric(
                                  label: 'Total Qty',
                                  value: '${controller.totalQuantity}',
                                ),
                              ),
                              Expanded(
                                child: _Metric(
                                  label: 'Total',
                                  value: _amount(controller.totalAmount),
                                ),
                              ),
                              Expanded(
                                child: _Metric(
                                  label: 'Balance',
                                  value: _amount(controller.balanceAmount),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.isPreparing.value)
                Container(
                  color: Colors.white.withValues(alpha: 0.72),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _DraftRepairTile extends StatelessWidget {
  const _DraftRepairTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final RepairDraftItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity} x ${_amount(item.rate)} = ${_amount(item.amount)}',
                ),
                if (item.attachmentPaths.isNotEmpty)
                  Text('${item.attachmentPaths.length} attachment(s)'),
                if (item.existingAttachments.isNotEmpty)
                  Text(
                    '${item.existingAttachments.length} saved attachment(s)',
                  ),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: const Color(0xFFF8F8F8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
  );
}

String _amount(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _attachmentLabel(String value) {
  final uri = Uri.tryParse(value);
  final segment = uri?.pathSegments.isNotEmpty == true
      ? uri!.pathSegments.last
      : value.split('/').last;
  return segment.trim().isEmpty ? 'Attachment' : segment;
}
