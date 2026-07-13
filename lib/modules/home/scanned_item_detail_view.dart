import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/order_models.dart';
import 'fallback_network_image.dart';
import 'home_controller.dart';

class ScannedItemDetailView extends StatefulWidget {
  const ScannedItemDetailView({super.key, required this.detail});

  final MergedItemDetailModel detail;

  @override
  State<ScannedItemDetailView> createState() => _ScannedItemDetailViewState();
}

class _ScannedItemDetailViewState extends State<ScannedItemDetailView> {
  final HomeController controller = Get.find<HomeController>();
  late int quantity;
  late final TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    quantity = 1;
    _quantityController = TextEditingController(text: quantity.toString());
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _setQuantity(int nextQuantity, {bool syncInput = true}) {
    final clamped = nextQuantity <= 0 ? 1 : nextQuantity;
    setState(() => quantity = clamped);
    if (syncInput) {
      _quantityController.value = TextEditingValue(
        text: clamped.toString(),
        selection: TextSelection.collapsed(offset: clamped.toString().length),
      );
    }
  }

  void _handleQuantityInput(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      setState(() => quantity = 0);
      return;
    }
    setState(() => quantity = parsed);
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(title: const Text('Item Details')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: quantity <= 0
                      ? null
                      : () {
                          controller.addToCart(
                            detail,
                            quantity: quantity,
                            showSuccessMessage: false,
                          );
                          Navigator.of(context).pop(true);
                          ApiResponseHandler.showSuccessSnackbar(
                            'Added to cart',
                          );
                        },
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: const Text('Add To Cart'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _ItemDetailsCard(detail: detail),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Quantity',
              child: Row(
                children: [
                  _StepButton(
                    icon: Icons.remove,
                    onTap: quantity > 1
                        ? () => _setQuantity(quantity - 1)
                        : null,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _quantityController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: _handleQuantityInput,
                        decoration: InputDecoration(
                          labelText: 'Qty',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add,
                    onTap: () => _setQuantity(quantity + 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemDetailsCard extends StatelessWidget {
  const _ItemDetailsCard({required this.detail});

  final MergedItemDetailModel detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 98,
                  height: 98,
                  color: Colors.white.withValues(alpha: 0.08),
                  child: FallbackNetworkImage(
                    imageUrls: [
                      ...detail.imageUrls,
                      if ((detail.image?.url ?? '').isNotEmpty)
                        detail.image!.url!,
                    ],
                    iconColor: Colors.white70,
                    iconSize: 36,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.itemName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      detail.itemGroup.isEmpty
                          ? 'Ungrouped item'
                          : detail.itemGroup,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(label: 'Code ${detail.itemCode}'),

                        if ((detail.hsnCode ?? '').isNotEmpty)
                          _InfoChip(label: 'HSN ${detail.hsnCode}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _DetailLine(label: 'Item Code', value: detail.itemCode),
          _DetailLine(label: 'Item Name', value: detail.itemName),
          _DetailLine(
            label: 'Group',
            value: detail.itemGroup.isEmpty ? '-' : detail.itemGroup,
          ),
          _DetailLine(label: 'HSN', value: detail.hsnCode ?? '-'),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.grey.shade200
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          color: onTap == null ? Colors.grey : AppColors.primary,
        ),
      ),
    );
  }
}
