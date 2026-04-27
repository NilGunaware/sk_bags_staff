import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/order_models.dart';
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

  @override
  void initState() {
    super.initState();
    quantity = widget.detail.availableOrderQuantity > 0 ? 1 : 0;
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
                  onPressed: () => Get.back(),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: detail.availableOrderQuantity <= 0
                      ? null
                      : () {
                          controller.addToCart(detail, quantity: quantity);
                          Get.back();
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
        child: Obx(() {
          final selectedCategory = controller.selectedPriceCategory;
          final selectedPrice = detail.priceFor(selectedCategory);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _HeroCard(
                detail: detail,
                selectedCategoryName:
                    selectedCategory?.categoryName ?? 'No Category',
                selectedPrice: selectedPrice.finalPrice,
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Stock Availability',
                child: Column(
                  children: [
                    _MetricRow(
                      label: ApiEndpoints.ahmLabel,
                      value: _formatNumber(
                        detail.quantityForServer(ApiEndpoints.ahmLabel),
                      ),
                    ),
                    const Divider(height: 20),
                    _MetricRow(
                      label: ApiEndpoints.bhuLabel,
                      value: _formatNumber(
                        detail.quantityForServer(ApiEndpoints.bhuLabel),
                      ),
                    ),
                    const Divider(height: 20),
                    _MetricRow(
                      label: 'Total Qty',
                      value: _formatNumber(detail.totalQuantity),
                      emphasized: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Selected Price',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricRow(
                      label: selectedPrice.categoryName,
                      value: _formatCurrency(selectedPrice.finalPrice),
                      emphasized: true,
                    ),
                    const SizedBox(height: 12),
                    _MetricRow(
                      label: 'Base Price',
                      value: _formatCurrency(selectedPrice.basePrice),
                    ),
                    const SizedBox(height: 8),
                    _MetricRow(
                      label: 'Discount',
                      value:
                          '${selectedPrice.discountPercent.toStringAsFixed(0)}%',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Add Quantity',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You can add up to ${detail.availableOrderQuantity} item(s) to the cart.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _StepButton(
                          icon: Icons.remove,
                          onTap: quantity > 1
                              ? () => setState(() => quantity -= 1)
                              : null,
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '$quantity',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        _StepButton(
                          icon: Icons.add,
                          onTap: quantity < detail.availableOrderQuantity
                              ? () => setState(() => quantity += 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (detail.warnings.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Server Notes',
                  child: Column(
                    children: detail.warnings
                        .map(
                          (warning) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Color(0xFFB45309),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(warning)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.detail,
    required this.selectedCategoryName,
    required this.selectedPrice,
  });

  final MergedItemDetailModel detail;
  final String selectedCategoryName;
  final double selectedPrice;

  @override
  Widget build(BuildContext context) {
    final imageUrl = detail.image?.url;

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
                  child: imageUrl == null || imageUrl.isEmpty
                      ? const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white70,
                          size: 36,
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.white70,
                                size: 36,
                              ),
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
                        _InfoChip(
                          label: 'QR ${detail.qrCode ?? detail.itemCode}',
                        ),
                        if ((detail.hsnCode ?? '').isNotEmpty)
                          _InfoChip(label: 'HSN ${detail.hsnCode}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: selectedCategoryName,
                  value: _formatCurrency(selectedPrice),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoTile(
                  label: 'Total Qty',
                  value: _formatNumber(detail.totalQuantity),
                ),
              ),
            ],
          ),
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

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: emphasized ? 18 : 15,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
      color: emphasized ? AppColors.primary : Colors.black87,
    );

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
        ),
        Text(value, style: valueStyle),
      ],
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
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

String _formatCurrency(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

String _formatNumber(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);
