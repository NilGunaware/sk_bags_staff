import 'package:flutter/material.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/order_models.dart';
import 'fallback_network_image.dart';

class LiveStockDetailView extends StatelessWidget {
  const LiveStockDetailView({super.key, required this.detail});

  final MergedItemDetailModel detail;

  @override
  Widget build(BuildContext context) {
    final ahmBranches = detail.branchesForServer(ApiEndpoints.ahmLabel);
    final bhuBranches = detail.branchesForServer(ApiEndpoints.bhuLabel);
    final visiblePrices = _visibleLiveStockPrices(detail.prices);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(title: const Text('Live Stock')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _LiveStockHero(detail: detail),
            const SizedBox(height: 16),
            _LiveStockSection(
              title: 'Server Stock',
              child: Column(
                children: [
                  _StockMetricTile(label: ApiEndpoints.ahmLabel, value: _formatNumber(detail.quantityForServer(ApiEndpoints.ahmLabel)), accentColor: const Color(0xFFD97706)),
                  const SizedBox(height: 10),
                  _StockMetricTile(label: ApiEndpoints.bhuLabel, value: _formatNumber(detail.quantityForServer(ApiEndpoints.bhuLabel)), accentColor: const Color(0xFF4C1D95)),
                  const SizedBox(height: 10),
                  _StockMetricTile(label: 'Total Qty', value: _formatNumber(detail.totalQuantity), accentColor: AppColors.primary),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _LiveStockSection(
              title: 'Branch Stock',
              child: Column(
                children: [
                  _BranchStockCard(title: ApiEndpoints.ahmLabel, branches: ahmBranches, accentColor: const Color(0xFFD97706)),
                  const SizedBox(height: 12),
                  _BranchStockCard(title: ApiEndpoints.bhuLabel, branches: bhuBranches, accentColor: const Color(0xFF4C1D95)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _LiveStockSection(
              title: 'All Prices',
              child: visiblePrices.isEmpty
                  ? const _EmptyCopy(message: 'No price rows found for this item.')
                  : Column(
                      children: visiblePrices
                          .map(
                            (price) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PriceRowCard(price: price),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            _LiveStockSection(
              title: 'Item Details',
              child: Column(
                children: [
                  _DetailRow(label: 'Item Code', value: detail.itemCode),
                  _DetailRow(label: 'QR Code', value: detail.qrCode?.isNotEmpty == true ? detail.qrCode! : detail.itemCode),
                  _DetailRow(label: 'Item Name', value: detail.itemName),
                  _DetailRow(label: 'Group', value: detail.itemGroup),
                  _DetailRow(label: 'HSN', value: detail.hsnCode ?? '-'),
                  _DetailRow(label: 'Stock Value', value: _formatNumber(detail.totalQuantityValue)),
                ],
              ),
            ),
            if (detail.supportItemCodes.isNotEmpty) ...[
              const SizedBox(height: 16),
              _LiveStockSection(
                title: 'Support Codes',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: detail.supportItemCodes
                      .map(
                        (code) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F6F6),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Text(
                            code,
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            if (detail.warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              _LiveStockSection(
                title: 'Server Notes',
                child: Column(
                  children: detail.warnings
                      .map(
                        (warning) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 18),
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
        ),
      ),
    );
  }
}

class _LiveStockHero extends StatelessWidget {
  const _LiveStockHero({required this.detail});

  final MergedItemDetailModel detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF1F1B2E), borderRadius: BorderRadius.circular(24)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 92,
              height: 92,
              color: Colors.white.withValues(alpha: 0.08),
              child: FallbackNetworkImage(imageUrls: [...detail.imageUrls, if ((detail.image?.url ?? '').isNotEmpty) detail.image!.url!], iconColor: Colors.white70, iconSize: 34),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.itemName,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(detail.itemGroup.isEmpty ? 'Ungrouped item' : detail.itemGroup, style: TextStyle(color: Colors.white.withValues(alpha: 0.72), height: 1.35)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroTag(label: 'Code ${detail.itemCode}'),
                    _HeroTag(label: 'QR ${(detail.qrCode?.isNotEmpty ?? false) ? detail.qrCode! : detail.itemCode}'),
                    _HeroTag(label: 'HSN ${detail.hsnCode ?? '-'}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _LiveStockSection extends StatelessWidget {
  const _LiveStockSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StockMetricTile extends StatelessWidget {
  const _StockMetricTile({required this.label, required this.value, required this.accentColor});

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: accentColor, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 17),
          ),
        ],
      ),
    );
  }
}

class _BranchStockCard extends StatelessWidget {
  const _BranchStockCard({required this.title, required this.branches, required this.accentColor});

  final String title;
  final List<BranchStockModel> branches;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              Text(
                '${branches.length} branch(es)',
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (branches.isEmpty)
            const _EmptyCopy(message: 'No branch-wise stock details were returned by this server.')
          else
            ...branches.map(
              (branch) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              branch.branchName,
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                            ),
                            // const SizedBox(height: 4),
                            // Text(
                            //   'Branch ${branch.branchCode}',
                            //   style: TextStyle(
                            //     color: Colors.grey.shade700,
                            //     fontSize: 12,
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Qty : ${_formatNumber(branch.quantity)} Pcs.',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
                          ),
                          // const SizedBox(height: 2),
                          // Text(
                          //   'Value ${_formatNumber(branch.quantityValue)}',
                          //   style: TextStyle(
                          //     color: Colors.grey.shade700,
                          //     fontSize: 12,
                          //   ),
                          // ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PriceRowCard extends StatelessWidget {
  const _PriceRowCard({required this.price});

  final ItemPriceModel price;

  @override
  Widget build(BuildContext context) {
    final displayCode = _displayLiveStockPriceCode(price);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                child: Text(
                  displayCode,
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  price.categoryName,
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                _formatNumber(price.finalPrice),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCopy extends StatelessWidget {
  const _EmptyCopy({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(message, style: TextStyle(color: Colors.grey.shade700, height: 1.4));
  }
}

String _formatNumber(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

List<ItemPriceModel> _visibleLiveStockPrices(List<ItemPriceModel> prices) {
  const order = <String>['A', 'W', 'C', 'H'];
  final filtered = prices.where((price) => order.contains(_displayLiveStockPriceCode(price))).toList();
  filtered.sort((a, b) => order.indexOf(_displayLiveStockPriceCode(a)).compareTo(order.indexOf(_displayLiveStockPriceCode(b))));
  return filtered;
}

String _displayLiveStockPriceCode(ItemPriceModel price) {
  final name = price.categoryName.trim().toUpperCase();
  if (name == 'W' || name.startsWith('W ')) {
    return 'W';
  }
  return price.categoryCode.trim().toUpperCase();
}
