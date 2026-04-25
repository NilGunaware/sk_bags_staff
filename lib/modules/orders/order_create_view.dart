import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/order_models.dart';
import 'order_create_controller.dart';

class OrderCreateView extends GetView<OrderCreateController> {
  const OrderCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(title: const Text('Create Order')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Obx(
          () => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _SubmitBar(
              lineCount: controller.selectedItems.length,
              totalQuantity: controller.totalQuantity,
              isPreparing: controller.isPreparing.value,
              isSubmitting: controller.isSubmitting.value,
              onSubmit:
                  controller.isPreparing.value || controller.isSubmitting.value
                  ? null
                  : controller.submit,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final selectedCount = controller.selectedItems.length;

          return Form(
            key: controller.formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 132),
              children: [
                _OrderHeroCard(
                  entryNo: controller.nextEntryNo.value,
                  entryDate: controller.displayEntryDate,
                  lineCount: selectedCount,
                  totalQuantity: controller.totalQuantity,
                  isPreparing: controller.isPreparing.value,
                ),
                const SizedBox(height: 16),
                _CreateSection(
                  icon: Icons.person_pin_circle_outlined,
                  title: 'Party Details',
                  subtitle: 'These values are sent to the remote order API.',
                  badge: 'Required',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: controller.partyNameController,
                        decoration: buildSoftInputDecoration(
                          labelText: 'Party Name',
                          hintText: 'Enter party name',
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Party name is required';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: controller.partyMobileController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: controller.mobileFormatters,
                        decoration: buildSoftInputDecoration(
                          labelText: 'Mobile No',
                          hintText: 'Enter mobile no',
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        validator: (value) {
                          final digits = (value ?? '').trim();
                          if (digits.isEmpty) {
                            return 'Mobile no is required';
                          }
                          if (digits.length < 10) {
                            return 'Enter a valid mobile no';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _CreateSection(
                  icon: Icons.inventory_2_outlined,
                  title: 'Order Items',
                  subtitle:
                      'Search items from ${ApiEndpoints.ahmLabel} and ${ApiEndpoints.bhuLabel}, then add them to the order. You can edit or remove items before submitting.',
                  badge: selectedCount == 0
                      ? 'Pending'
                      : '$selectedCount added',
                  action: ElevatedButton.icon(
                    onPressed:
                        controller.isPreparing.value ||
                            controller.isSubmitting.value
                        ? null
                        : () => _openItemPicker(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _SummaryChip(
                            icon: Icons.list_alt_outlined,
                            label: '$selectedCount line(s)',
                          ),
                          _SummaryChip(
                            icon: Icons.inventory_2_outlined,
                            label: '${controller.totalQuantity} total qty',
                            emphasized: selectedCount > 0,
                          ),
                          if (controller.syncWarnings.isNotEmpty)
                            _SummaryChip(
                              icon: Icons.sync_problem_outlined,
                              label:
                                  '${controller.syncWarnings.length} sync alert(s)',
                            ),
                        ],
                      ),
                      if (controller.syncWarnings.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (final warning in controller.syncWarnings)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _WarningBanner(message: warning),
                          ),
                      ],
                      const SizedBox(height: 16),
                      if (controller.selectedItems.isEmpty)
                        const _OrderCreateEmptyState(
                          icon: Icons.search_outlined,
                          title: 'No items added yet',
                          subtitle:
                              'Tap "Add Item" to search both item servers and pick stock.',
                        )
                      else
                        for (final item in controller.selectedItems) ...[
                          _SelectedItemCard(
                            item: item,
                            onEdit: () => _editItem(context, item),
                            onRemove: () => controller.removeItem(item),
                          ),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Future<void> _openItemPicker(BuildContext context) async {
    final item = await showModalBottomSheet<MergedItemModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _ItemPickerSheet(controller: controller),
      ),
    );

    if (item == null || !context.mounted) {
      return;
    }
    await _showQuantityDialog(context, item);
  }

  Future<void> _editItem(BuildContext context, DraftOrderItem item) async {
    final merged = MergedItemModel(
      itemCode: item.itemCode,
      itemName: item.itemName,
      totalQuantity: item.availableQuantity,
      serverQuantities: const <String, int>{},
      qrCode: null,
    );

    await _showQuantityDialog(context, merged, editing: item);
  }

  Future<void> _showQuantityDialog(
    BuildContext context,
    MergedItemModel item, {
    DraftOrderItem? editing,
  }) async {
    final maxAllowed = controller.maxAllowedFor(item, editing: editing);
    if (maxAllowed <= 0) {
      Get.snackbar(
        '',
        'No more stock is available for this item.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    final quantity = await showDialog<int>(
      context: context,
      builder: (_) => _QuantityDialog(
        item: item,
        maxAllowed: maxAllowed,
        initialQuantity: editing?.quantity ?? 1,
        isEditing: editing != null,
      ),
    );

    if (quantity == null) {
      return;
    }
    controller.upsertItem(item, quantity, editing: editing);
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({
    required this.item,
    required this.maxAllowed,
    required this.initialQuantity,
    required this.isEditing,
  });

  final MergedItemModel item;
  final int maxAllowed;
  final int initialQuantity;
  final bool isEditing;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController _qtyController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.initialQuantity.toString(),
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = int.tryParse(_qtyController.text.trim()) ?? 0;
    if (quantity <= 0 || quantity > widget.maxAllowed) {
      setState(() {
        _errorText = 'Enter a value between 1 and ${widget.maxAllowed}';
      });
      return;
    }
    Navigator.of(context).pop(quantity);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Text(item.itemName.isEmpty ? item.itemCode : item.itemName),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Item code: ${item.itemCode.isEmpty ? '-' : item.itemCode}',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Available total quantity: ${item.totalQuantity}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You can enter up to ${widget.maxAllowed} for this order.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: buildSoftInputDecoration(
                labelText: 'Quantity',
                hintText: 'Enter quantity',
                errorText: _errorText,
                prefixIcon: const Icon(Icons.format_list_numbered),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}

InputDecoration buildSoftInputDecoration({
  required String labelText,
  required String hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? errorText,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    errorText: errorText,
    filled: true,
    fillColor: const Color(0xFFF8F8F8),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(Colors.black12),
    enabledBorder: border(Colors.black12),
    focusedBorder: border(AppColors.primary, 1.2),
    errorBorder: border(Colors.red.shade300),
    focusedErrorBorder: border(Colors.red.shade400, 1.2),
  );
}

class _CreateSection extends StatelessWidget {
  const _CreateSection({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.icon,
    this.action,
    this.badge,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final IconData icon;
  final Widget? action;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useStackedHeader = action != null && constraints.maxWidth < 560;

          Widget buildHeader() {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            _HeaderBadge(label: badge!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (useStackedHeader) ...[
                buildHeader(),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: action),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: buildHeader()),
                    if (action != null) ...[const SizedBox(width: 12), action!],
                  ],
                ),
              const SizedBox(height: 16),
              child,
            ],
          );
        },
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.primary.withValues(alpha: 0.08)
            : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized
              ? AppColors.primary.withValues(alpha: 0.14)
              : Colors.black12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderHeroCard extends StatelessWidget {
  const _OrderHeroCard({
    required this.entryNo,
    required this.entryDate,
    required this.lineCount,
    required this.totalQuantity,
    required this.isPreparing,
  });

  final int entryNo;
  final String entryDate;
  final int lineCount;
  final int totalQuantity;
  final bool isPreparing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF111111), Color(0xFF2B2B2B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Draft',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPreparing ? 'Preparing entry no...' : 'Entry #$entryNo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entryDate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroStat(label: 'Line Items', value: '$lineCount'),
              _HeroStat(label: 'Total Qty', value: '$totalQuantity'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.lineCount,
    required this.totalQuantity,
    required this.isPreparing,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final int lineCount;
  final int totalQuantity;
  final bool isPreparing;
  final bool isSubmitting;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _SubmitMetric(label: 'Lines', value: '$lineCount'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SubmitMetric(label: 'Qty', value: '$totalQuantity'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSubmit,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                isSubmitting
                    ? 'Submitting...'
                    : isPreparing
                    ? 'Preparing Order...'
                    : 'Create Order',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitMetric extends StatelessWidget {
  const _SubmitMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedItemCard extends StatelessWidget {
  const _SelectedItemCard({
    required this.item,
    required this.onEdit,
    required this.onRemove,
  });

  final DraftOrderItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName.isEmpty ? item.itemCode : item.itemName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.itemCode.isEmpty
                          ? 'Item code unavailable'
                          : 'Code: ${item.itemCode}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Qty',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ItemTag(
                icon: Icons.inventory_2_outlined,
                label: 'Available ${item.availableQuantity}',
              ),
              _ItemTag(
                icon: Icons.shopping_basket_outlined,
                label: 'Selected ${item.quantity}',
                emphasized: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Qty'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    backgroundColor: Colors.red.shade50,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemTag extends StatelessWidget {
  const _ItemTag({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.primary.withValues(alpha: 0.08)
            : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1D39A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF9C6200)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF9C6200),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCreateEmptyState extends StatelessWidget {
  const _OrderCreateEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(icon, color: AppColors.primary, size: 30),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _ItemPickerSheet extends StatefulWidget {
  const _ItemPickerSheet({required this.controller});

  final OrderCreateController controller;

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  static const int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<MergedItemModel> _items = <MergedItemModel>[];
  List<MergedItemModel> _cachedItems = <MergedItemModel>[];
  List<String> _warnings = <String>[];
  bool _isLoading = false;
  bool _hasMore = false;
  int _nextPage = 1;
  int _nextLocalPage = 1;
  String? _errorMessage;
  bool _isShowingLocalResults = false;
  String? _pendingRemoteQuery;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRemote(reset: true, query: '');
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      _applySearchStrategy(_searchController.text.trim());
    });
  }

  void _applySearchStrategy(String query) {
    final localPage = widget.controller.filterLoadedItems(
      items: _cachedItems,
      page: 1,
      pageSize: _pageSize,
      query: query,
      warnings: _warnings,
    );

    if (localPage.items.isNotEmpty ||
        (query.isEmpty && _cachedItems.isNotEmpty)) {
      _applyLocalResults(page: 1, query: query);
      return;
    }

    _loadRemote(reset: true, query: query);
  }

  void _applyLocalResults({
    required int page,
    required String query,
    bool append = false,
  }) {
    final result = widget.controller.filterLoadedItems(
      items: _cachedItems,
      page: page,
      pageSize: _pageSize,
      query: query,
      warnings: _warnings,
    );

    setState(() {
      _isShowingLocalResults = true;
      _errorMessage = null;
      _warnings = <String>[];
      _items = append
          ? <MergedItemModel>[..._items, ...result.items]
          : result.items;
      _hasMore = result.hasMore;
      _nextLocalPage = page + 1;
    });
    widget.controller.syncWarnings.clear();
  }

  void _mergeFetchedItemsIntoCache(List<MergedItemModel> incoming) {
    final mergedCache = <String, MergedItemModel>{
      for (final item in _cachedItems) item.key: item,
    };

    for (final item in incoming) {
      final existing = mergedCache[item.key];
      if (existing == null) {
        mergedCache[item.key] = item;
        continue;
      }

      final mergedServerQuantities = <String, int>{
        ...existing.serverQuantities,
        ...item.serverQuantities,
      };

      mergedCache[item.key] = MergedItemModel(
        itemCode: item.itemCode.isNotEmpty ? item.itemCode : existing.itemCode,
        itemName: item.itemName.isNotEmpty ? item.itemName : existing.itemName,
        totalQuantity: mergedServerQuantities.values.fold<int>(
          0,
          (sum, quantity) => sum + quantity,
        ),
        serverQuantities: mergedServerQuantities,
        qrCode: (item.qrCode?.trim().isNotEmpty ?? false)
            ? item.qrCode
            : existing.qrCode,
      );
    }

    _cachedItems = mergedCache.values.toList()
      ..sort((a, b) {
        final codeCompare = a.itemCode.compareTo(b.itemCode);
        if (codeCompare != 0) {
          return codeCompare;
        }
        return a.itemName.compareTo(b.itemName);
      });
  }

  Future<void> _load({required bool reset}) async {
    if (_isShowingLocalResults) {
      if (!reset && !_hasMore) {
        return;
      }

      _applyLocalResults(
        page: reset ? 1 : _nextLocalPage,
        query: _searchController.text.trim(),
        append: !reset,
      );
      return;
    }

    await _loadRemote(reset: reset, query: _searchController.text.trim());
  }

  Future<void> _loadRemote({required bool reset, required String query}) async {
    if (_isLoading) {
      _pendingRemoteQuery = query.trim();
      return;
    }

    final requestQuery = query.trim();
    _pendingRemoteQuery = null;

    setState(() {
      _isLoading = true;
      if (reset) {
        _errorMessage = null;
        _nextPage = 1;
        _isShowingLocalResults = false;
      }
    });

    try {
      final pageToLoad = reset ? 1 : _nextPage;
      final result = await widget.controller.searchItems(
        page: pageToLoad,
        pageSize: _pageSize,
        query: requestQuery,
      );

      if (!mounted) {
        return;
      }

      _mergeFetchedItemsIntoCache(result.items);

      final latestQuery = _searchController.text.trim();
      if (latestQuery != requestQuery) {
        _pendingRemoteQuery = latestQuery;
        return;
      }

      setState(() {
        _warnings = result.items.isEmpty ? result.warnings : <String>[];
        _hasMore = result.hasMore;
        _isShowingLocalResults = false;
        _items = reset
            ? result.items
            : <MergedItemModel>[..._items, ...result.items];
        _nextPage = pageToLoad + 1;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage =
            'Unable to load items right now. Check the dashboard status and try again.';
        _hasMore = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      final queuedQuery = _pendingRemoteQuery;
      if (mounted && queuedQuery != null) {
        _pendingRemoteQuery = null;
        Future<void>.microtask(() => _applySearchStrategy(queuedQuery));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Search Items',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    'Search by item code or name and pick merged stock from ${ApiEndpoints.ahmLabel} and ${ApiEndpoints.bhuLabel}.',
                    style: TextStyle(color: Colors.grey.shade600, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SummaryChip(
                        icon: Icons.inventory_outlined,
                        label: '${_items.length} result(s)',
                      ),
                      const _SummaryChip(
                        icon: Icons.dns_outlined,
                        label:
                            '${ApiEndpoints.ahmLabel} + ${ApiEndpoints.bhuLabel}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) =>
                    _applySearchStrategy(_searchController.text.trim()),
                decoration: buildSoftInputDecoration(
                  labelText: 'Item code or item name',
                  hintText:
                      'Search from ${ApiEndpoints.ahmLabel} and ${ApiEndpoints.bhuLabel}',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: () {
                      _searchController.clear();
                      _applySearchStrategy('');
                    },
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear',
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _loadRemote(
                              reset: true,
                              query: _searchController.text.trim(),
                            ),
                      icon: const Icon(Icons.search),
                      label: const Text('Search Servers'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_warnings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (final warning in _warnings) ...[
                      _WarningBanner(message: warning),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Expanded(
              child: _isLoading && _items.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _errorMessage != null && _items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off_outlined,
                              size: 42,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _load(reset: true),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _items.isEmpty
                  ? _OrderCreateEmptyState(
                      icon: _warnings.isNotEmpty
                          ? Icons.cloud_off_outlined
                          : Icons.inventory_2_outlined,
                      title: _warnings.isNotEmpty
                          ? 'Item servers unavailable'
                          : 'No items matched',
                      subtitle: _warnings.isNotEmpty
                          ? 'Check the dashboard status. If either ${ApiEndpoints.ahmLabel} or ${ApiEndpoints.bhuLabel} is running, search will continue to work.'
                          : 'Try a different code or name to search ${ApiEndpoints.ahmLabel} and ${ApiEndpoints.bhuLabel}.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: _items.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _items.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: OutlinedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _load(reset: false),
                              icon: const Icon(Icons.expand_more),
                              label: Text(
                                _isLoading ? 'Loading...' : 'Load More',
                              ),
                            ),
                          );
                        }

                        final item = _items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () => Navigator.of(context).pop(item),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.inventory_2_outlined,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.itemName.isEmpty
                                                    ? item.itemCode
                                                    : item.itemName,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item.itemCode.isEmpty
                                                    ? 'Item code unavailable'
                                                    : 'Code: ${item.itemCode}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              const Text(
                                                'Total',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                '${item.totalQuantity}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        const _ItemTag(
                                          icon: Icons.sync_alt_outlined,
                                          label: 'Merged stock ready',
                                          emphasized: true,
                                        ),
                                        if ((item.qrCode ?? '')
                                            .trim()
                                            .isNotEmpty)
                                          _ItemTag(
                                            icon: Icons.qr_code_2_outlined,
                                            label: 'QR ${item.qrCode}',
                                          ),
                                      ],
                                    ),
                                    if (item.serverQuantities.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: item.serverQuantities.entries
                                            .map(
                                              (entry) => _ServerQtyTag(
                                                serverName: entry.key,
                                                quantity: entry.value,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerQtyTag extends StatelessWidget {
  const _ServerQtyTag({required this.serverName, required this.quantity});

  final String serverName;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$serverName: $quantity',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
