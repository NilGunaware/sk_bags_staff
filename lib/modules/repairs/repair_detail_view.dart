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
    // Safety check: Don't allow edit if it's a Karigar repair
    if (controller.isKarigar.value) return;

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
          title: Obx(
            () => Text(
              controller.isKarigar.value ? 'Karigar Detail' : 'Repair Detail',
            ),
          ),
          actions: [
            Obx(() {
              final detail = controller.detail.value;
              // CONDITION: Hide edit button if data is from Karigar Repairing
              if (controller.isKarigar.value) {
                return const SizedBox.shrink();
              }

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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                'Repair #${summary.entryNo.isEmpty ? summary.id : summary.entryNo}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            _StatusChip(status: summary.status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(label: 'Party', value: summary.partyName),
                        _InfoRow(label: 'Mobile', value: summary.partyMobile),
                        if (summary.locationName.isNotEmpty)
                          _InfoRow(
                            label: summary.branchName.isNotEmpty
                                ? 'Branch'
                                : 'Shop',
                            value: summary.locationName,
                          ),
                        if (summary.karigarName.isNotEmpty)
                          _InfoRow(
                            label: 'Karigar',
                            value: summary.karigarName,
                          ),
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
                            label: 'QTY',
                            value: '${summary.totalQty}',
                          ),
                        ),
                        Expanded(
                          child: _Metric(
                            label: 'Total Amount',
                            value: _amount(summary.totalAmount),
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
                        Text(
                          'Items (${detail?.items.length ?? 0})',
                          style: const TextStyle(
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
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qty',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _amount(item.amount),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.instruction.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Instruction: ${item.instruction}',
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
            ),
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

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: FallbackNetworkImage(
                  imageUrls: [imageUrl],
                  fit: BoxFit.contain,
                  iconColor: Colors.white70,
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final attachment in attachments)
          GestureDetector(
            onTap: () => _showImagePreview(context, attachment),
            child: SizedBox(
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
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final int status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        repairStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
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

Color _statusColor(int status) {
  return switch (status) {
    1 => const Color(0xFF15803D),
    2 => const Color(0xFFB91C1C),
    _ => const Color(0xFFB45309),
  };
}
