import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/order_models.dart';
import '../home/fallback_network_image.dart';
import '../home/searchable_item_lookup_sheet.dart';
import 'order_create_controller.dart';

class OrderCreateView extends GetView<OrderCreateController> {
  const OrderCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(title: Text(controller.screenTitle)),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Obx(
          () => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _SubmitBar(
              lineCount: controller.lineCount,
              totalQuantity: controller.totalQuantity,
              totalAmount: controller.totalAmount,
              isPreparing: controller.isPreparing.value,
              isSubmitting: controller.isSubmitting.value,
              submitLabel: controller.submitLabel,
              submittingLabel: controller.submittingLabel,
              preparingLabel: controller.preparingLabel,
              onSubmit:
                  controller.isPreparing.value || controller.isSubmitting.value
                  ? null
                  : controller.submit,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: controller.formKey,
          child: Obx(() {
            final items = controller.cartItems.toList();
            final selectedCategory = controller.selectedPriceCategory.value;

            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                bottomInset > 0 ? bottomInset + 150 : 150,
              ),
              children: [
                _OrderCartHero(
                  title: controller.heroTitle,
                  entryNo: controller.nextEntryNo.value,
                  entryDate: controller.displayEntryDate,
                  lineCount: controller.lineCount,
                  totalQuantity: controller.totalQuantity,
                  totalAmount: controller.totalAmount,
                ),
                const SizedBox(height: 16),
                _PartyCard(controller: controller),
                const SizedBox(height: 16),
                _PriceSelector(
                  categories: controller.priceCategories,
                  selectedCategory: selectedCategory,
                  onSelected: controller.selectPriceCategory,
                ),
                _LookupCard(
                  isLoading: controller.isLookingUpItem.value,
                  onTap: () => _openLookupSheet(context),
                ),
                const SizedBox(height: 16),
                if (controller.isHydratingOrderItems.value) ...[
                  const _InlineBanner(
                    icon: Icons.sync_outlined,
                    message: 'Loading live item details, prices, and images...',
                    color: AppColors.primary,
                    backgroundColor: Color(0xFFEFF3FF),
                  ),
                  const SizedBox(height: 12),
                ],
                if (controller.syncWarnings.isNotEmpty) ...[
                  for (final warning in controller.syncWarnings) ...[
                    _InlineBanner(
                      icon: Icons.info_outline,
                      message: warning,
                      color: Colors.orange.shade800,
                      backgroundColor: Colors.orange.shade50,
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 4),
                ],
                if (items.isEmpty)
                  const _EmptyCartCard()
                else ...[
                  for (final item in items) ...[
                    _OrderCartItemCard(
                      item: item,
                      selectedPrice: controller.selectedPriceForCartItem(item),
                      onDecrease: item.quantity > 1
                          ? () => controller.updateCartItemQuantity(
                              item,
                              item.quantity - 1,
                            )
                          : null,
                      onIncrease: () => controller.updateCartItemQuantity(
                        item,
                        item.quantity + 1,
                      ),
                      onQuantityChanged: (quantity) =>
                          controller.updateCartItemQuantity(item, quantity),
                      onRemove: () => controller.removeCartItem(item),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _TotalsCard(
                    lineCount: controller.lineCount,
                    totalQuantity: controller.totalQuantity,
                    totalAmount: controller.totalAmount,
                  ),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }

  Future<void> _openLookupSheet(BuildContext context) async {
    final lookup = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SearchableItemLookupSheet(
        title: 'Add Order Item',
        subtitle: 'Search by item code/name or scan QR to add an item.',
      ),
    );

    if (lookup == null || lookup.trim().isEmpty) {
      return;
    }
    await controller.addItemByLookup(lookup);
  }
}

class _OrderCartHero extends StatelessWidget {
  const _OrderCartHero({
    required this.title,
    required this.entryNo,
    required this.entryDate,
    required this.lineCount,
    required this.totalQuantity,
    required this.totalAmount,
  });

  final String title;
  final int entryNo;
  final String entryDate;
  final int lineCount;
  final int totalQuantity;
  final double totalAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Order #${entryNo <= 0 ? '-' : entryNo} • $entryDate',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroChip(
                icon: Icons.list_alt_outlined,
                label: '$lineCount line(s)',
              ),
              _HeroChip(
                icon: Icons.inventory_2_outlined,
                label: '$totalQuantity qty',
              ),
              _HeroChip(
                icon: Icons.payments_outlined,
                label: _formatAmount(totalAmount),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({required this.controller});

  final OrderCreateController controller;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Party Details',
      subtitle: 'Customer name and mobile number are required before saving.',
      child: Column(
        children: [
          TextFormField(
            controller: controller.partyNameController,
            textInputAction: TextInputAction.next,
            scrollPadding: const EdgeInsets.only(bottom: 180),
            decoration: _softInputDecoration(
              labelText: 'Party Name',
              hintText: 'Enter party name',
              prefixIcon: const Icon(Icons.person_outline),
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Party name is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller.partyMobileController,
            keyboardType: TextInputType.phone,
            inputFormatters: controller.mobileFormatters,
            textInputAction: TextInputAction.done,
            scrollPadding: const EdgeInsets.only(bottom: 180),
            decoration: _softInputDecoration(
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
    );
  }
}

class _PriceSelector extends StatelessWidget {
  const _PriceSelector({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<PriceCategoryModel> categories;
  final PriceCategoryModel? selectedCategory;
  final ValueChanged<PriceCategoryModel> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _SectionCard(
        title: 'Price',
        subtitle: 'Selected price is used for cart amount preview.',
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories
                .map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category.displayName),
                      selected:
                          selectedCategory?.categoryNo == category.categoryNo,
                      onSelected: (_) => onSelected(category),
                      selectedColor: AppColors.primary,
                      backgroundColor: const Color(0xFFF6F6F6),
                      labelStyle: TextStyle(
                        color:
                            selectedCategory?.categoryNo == category.categoryNo
                            ? Colors.white
                            : AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                      side: BorderSide(
                        color:
                            selectedCategory?.categoryNo == category.categoryNo
                            ? AppColors.primary
                            : Colors.black12,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _LookupCard extends StatelessWidget {
  const _LookupCard({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Add Item',
      subtitle: 'Scan QR or enter an item code to add more lines.',
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : onTap,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.qr_code_scanner_outlined),
          label: Text(isLoading ? 'Searching...' : 'Scan QR / Add Item'),
        ),
      ),
    );
  }
}

class _OrderCartItemCard extends StatelessWidget {
  const _OrderCartItemCard({
    required this.item,
    required this.selectedPrice,
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final CartItemModel item;
  final ItemPriceModel selectedPrice;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasOpenLimit = item.availableQuantity >= 999999;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 62,
                  height: 62,
                  color: AppColors.primary.withValues(alpha: 0.06),
                  child: FallbackNetworkImage(
                    imageUrls: [
                      ...item.imageUrls,
                      if ((item.imageUrl ?? '').isNotEmpty) item.imageUrl!,
                    ],
                    iconColor: AppColors.primary,
                    iconSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName.isEmpty ? 'No item name' : item.itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Code ${item.itemCode.isEmpty ? '-' : item.itemCode} • ${selectedPrice.displayName}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Price ${_formatAmount(selectedPrice.finalPrice)} • Stock ${hasOpenLimit ? 'not checked' : item.availableQuantity}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QtyIconButton(icon: Icons.remove, onTap: onDecrease),
              SizedBox(
                width: 86,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _OrderCartQuantityInput(
                    quantity: item.quantity,
                    onChanged: onQuantityChanged,
                  ),
                ),
              ),
              _QtyIconButton(icon: Icons.add, onTap: onIncrease),
              const Spacer(),
              Text(
                _formatAmount(selectedPrice.finalPrice * item.quantity),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderCartQuantityInput extends StatefulWidget {
  const _OrderCartQuantityInput({
    required this.quantity,
    required this.onChanged,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  State<_OrderCartQuantityInput> createState() =>
      _OrderCartQuantityInputState();
}

class _OrderCartQuantityInputState extends State<_OrderCartQuantityInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.quantity.toString());
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _OrderCartQuantityInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final visibleQuantity = int.tryParse(_controller.text.trim());
    if (widget.quantity != oldWidget.quantity &&
        (!_focusNode.hasFocus || visibleQuantity != widget.quantity)) {
      _setText(widget.quantity.toString());
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      _commitQuantity();
    }
  }

  void _setText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _commitQuantity() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null) {
      _setText(widget.quantity.toString());
      return;
    }
    _applyQuantity(parsed);
  }

  void _applyQuantity(int parsed) {
    final clamped = parsed <= 0 ? 1 : parsed;
    _setText(clamped.toString());
    if (clamped != widget.quantity) {
      widget.onChanged(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) {
          _applyQuantity(parsed);
        }
      },
      onSubmitted: (_) => _commitQuantity(),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      ),
    );
  }
}

class _QtyIconButton extends StatelessWidget {
  const _QtyIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.grey.shade200
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? Colors.grey : AppColors.primary,
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.lineCount,
    required this.totalQuantity,
    required this.totalAmount,
  });

  final int lineCount;
  final int totalQuantity;
  final double totalAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          _CartTotalRow(label: 'Items', value: '$lineCount'),
          const SizedBox(height: 10),
          _CartTotalRow(label: 'Total Qty', value: '$totalQuantity'),
          const SizedBox(height: 10),
          _CartTotalRow(
            label: 'Amount',
            value: _formatAmount(totalAmount),
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _CartTotalRow extends StatelessWidget {
  const _CartTotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
            fontSize: emphasized ? 18 : 15,
          ),
        ),
      ],
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.lineCount,
    required this.totalQuantity,
    required this.totalAmount,
    required this.isPreparing,
    required this.isSubmitting,
    required this.submitLabel,
    required this.submittingLabel,
    required this.preparingLabel,
    required this.onSubmit,
  });

  final int lineCount;
  final int totalQuantity;
  final double totalAmount;
  final bool isPreparing;
  final bool isSubmitting;
  final String submitLabel;
  final String submittingLabel;
  final String preparingLabel;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$lineCount item(s) • $totalQuantity qty',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatAmount(totalAmount),
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onSubmit,
            child: isPreparing || isSubmitting
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(isPreparing ? preparingLabel : submittingLabel),
                    ],
                  )
                : Text(submitLabel),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EmptyCartCard extends StatelessWidget {
  const _EmptyCartCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            color: Colors.grey.shade400,
            size: 40,
          ),
          const SizedBox(height: 10),
          const Text(
            'No items added',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Scan QR / Add Item" to add lines before saving.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({
    required this.icon,
    required this.message,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final String message;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _softInputDecoration({
  required String labelText,
  required String hintText,
  Widget? prefixIcon,
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

String _formatAmount(double value) => value.round().toString();
