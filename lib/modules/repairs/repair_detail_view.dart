import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/api_response_handler.dart';
import '../../data/models/repair_models.dart';
import '../../routes/app_routes.dart';
import '../home/fallback_network_image.dart';
import 'repair_detail_controller.dart';

class RepairDetailView extends GetView<RepairDetailController> {
  const RepairDetailView({super.key});

  Future<void> _openUpdateRepair() async {
    final detail = controller.detail.value;
    if (detail == null || controller.isLoading.value) return;

    final result = await Get.toNamed(Routes.repairCreate, arguments: detail);
    final updated =
        result == true || (result is Map && result['updated'] == true);
    if (!updated) return;

    controller.wasUpdated = true;
    await controller.fetchDetail();
    final message = result is Map
        ? (result['message'] ?? 'Repair updated successfully').toString()
        : 'Repair updated successfully';
    ApiResponseHandler.showSuccessSnackbar(message);
  }

  void _goBack(BuildContext context) {
    Navigator.of(context).pop<Map<String, dynamic>?>(
      controller.wasUpdated ? <String, dynamic>{'updated': true} : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Map<String, dynamic>?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffold,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => _goBack(context),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Repair Detail'),
          actions: [
            Obx(() {
              final detail = controller.detail.value;
              return IconButton(
                onPressed: detail == null ? null : _openUpdateRepair,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit repair',
              );
            }),
          ],
        ),
        body: SafeArea(
          child: Obx(() {
            final summary =
                controller.detail.value?.summary ?? controller.repair.value;
            final detail = controller.detail.value;

            if (controller.isLoading.value && detail == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (summary == null) {
              return const Center(child: Text('Repair not found.'));
            }

            return RefreshIndicator(
              onRefresh: controller.fetchDetail,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  if (controller.errorMessage.value != null) ...[
                    _Message(message: controller.errorMessage.value!),
                    const SizedBox(height: 14),
                  ],
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Repair #${summary.entryNo.isEmpty ? '-' : summary.entryNo}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(label: 'Party', value: summary.partyName),
                        _InfoRow(label: 'Mobile', value: summary.partyMobile),
                        _InfoRow(label: 'Entry Date', value: summary.entryDate),
                        _InfoRow(
                          label: 'Delivery',
                          value: summary.deliveryDate,
                        ),
                        if (summary.notes.isNotEmpty)
                          _InfoRow(label: 'Notes', value: summary.notes),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    child: Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            label: 'Qty',
                            value: '${summary.totalQty}',
                          ),
                        ),
                        Expanded(
                          child: _Metric(
                            label: 'Total',
                            value: _amount(summary.totalAmount),
                          ),
                        ),
                        Expanded(
                          child: _Metric(
                            label: 'Balance',
                            value: _amount(summary.balanceAmount),
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
                        const Text(
                          'Items',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (detail == null || detail.items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: Text('No repair items found.'),
                            ),
                          )
                        else
                          for (final item in detail.items)
                            _RepairItemCard(item: item),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _RepairItemCard extends StatelessWidget {
  const _RepairItemCard({required this.item});

  final RepairItemModel item;

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
          if (item.instruction.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.instruction),
          ],
          if (item.attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            _AttachmentGrid(attachments: item.attachments),
          ],
        ],
      ),
    );
  }
}

class _AttachmentGrid extends StatelessWidget {
  const _AttachmentGrid({required this.attachments});

  final List<String> attachments;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final attachment in attachments)
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 96,
                    height: 82,
                    color: Colors.white,
                    child: FallbackNetworkImage(
                      imageUrls: [attachment],
                      iconColor: AppColors.primary,
                      iconSize: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _attachmentLabel(attachment),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
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

class _Message extends StatelessWidget {
  const _Message({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Text(message),
    );
  }
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
