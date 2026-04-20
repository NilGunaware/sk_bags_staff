import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      body: SafeArea(
        child: Obx(() {
          return Form(
            key: controller.formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _CreateHero(controller: controller),
                const SizedBox(height: 16),
                _CreateSection(
                  title: 'Party Details',
                  subtitle: 'These values are sent to the remote order API.',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: controller.partyNameController,
                        decoration: const InputDecoration(
                          labelText: 'Party Name',
                          hintText: 'Enter party name',
                          prefixIcon: Icon(Icons.person_outline),
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
                        decoration: const InputDecoration(
                          labelText: 'Mobile No',
                          hintText: 'Enter mobile no',
                          prefixIcon: Icon(Icons.phone_outlined),
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
                  title: 'Order Items',
                  subtitle:
                      'Search items from Server 1 and Server 2, then use the merged total quantity.',
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
                            label: '${controller.selectedItems.length} line(s)',
                          ),
                          _SummaryChip(
                            icon: Icons.inventory_2_outlined,
                            label: '${controller.totalQuantity} total qty',
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
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed:
                      controller.isPreparing.value ||
                          controller.isSubmitting.value
                      ? null
                      : controller.submit,
                  icon: controller.isSubmitting.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    controller.isSubmitting.value
                        ? 'Submitting...'
                        : 'Create Order',
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

    final qtyController = TextEditingController(
      text: (editing?.quantity ?? 1).toString(),
    );

    final quantity = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                item.itemName.isEmpty ? item.itemCode : item.itemName,
              ),
              content: Column(
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
                    'You can enter up to $maxAllowed for this order.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      errorText: errorText,
                      prefixIcon: const Icon(Icons.format_list_numbered),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final quantity =
                        int.tryParse(qtyController.text.trim()) ?? 0;
                    if (quantity <= 0 || quantity > maxAllowed) {
                      setState(() {
                        errorText = 'Enter a value between 1 and $maxAllowed';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(quantity);
                  },
                  child: Text(editing == null ? 'Add' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );

    qtyController.dispose();

    if (quantity == null) {
      return;
    }
    controller.upsertItem(item, quantity, editing: editing);
  }
}

class _CreateHero extends StatelessWidget {
  const _CreateHero({required this.controller});

  final OrderCreateController controller;

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
          const Text(
            'Remote Order Entry',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders are saved to https://interlinkpos.com/sk_bags/api/v1 while item availability is merged from both local item servers.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          if (controller.isPreparing.value)
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Preparing order number...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HeroBadge(
                  icon: Icons.receipt_long_outlined,
                  label: 'Order No ${controller.nextEntryNo.value}',
                ),
                _HeroBadge(
                  icon: Icons.calendar_today_outlined,
                  label: controller.displayEntryDate,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

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

class _CreateSection extends StatelessWidget {
  const _CreateSection({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
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
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
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
              if (action != null) ...[const SizedBox(width: 12), action!],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(999),
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
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.itemName.isEmpty ? item.itemCode : item.itemName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit quantity',
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove item',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ItemTag(
                icon: Icons.qr_code_2_outlined,
                label: item.itemCode.isEmpty ? 'No code' : item.itemCode,
              ),
              _ItemTag(
                icon: Icons.inventory_2_outlined,
                label: 'Available ${item.availableQuantity}',
              ),
              _ItemTag(
                icon: Icons.shopping_basket_outlined,
                label: 'Selected ${item.quantity}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemTag extends StatelessWidget {
  const _ItemTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
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
        CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFFF1F1F1),
          child: Icon(icon, color: AppColors.primary, size: 28),
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
  final TextEditingController _searchController = TextEditingController();

  List<MergedItemModel> _items = <MergedItemModel>[];
  List<String> _warnings = <String>[];
  bool _isLoading = false;
  bool _hasMore = false;
  int _nextPage = 1;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load(reset: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      if (reset) {
        _errorMessage = null;
        _nextPage = 1;
      }
    });

    try {
      final result = await widget.controller.searchItems(
        page: _nextPage,
        pageSize: 20,
        query: _searchController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _warnings = result.warnings;
        _hasMore = result.hasMore;
        _items = reset
            ? result.items
            : <MergedItemModel>[..._items, ...result.items];
        _nextPage++;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
              child: Row(
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(reset: true),
                decoration: InputDecoration(
                  labelText: 'Item code or item name',
                  hintText: 'Search from Server 1 and Server 2',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: () {
                      _searchController.clear();
                      _load(reset: true);
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
                      onPressed: _isLoading ? null : () => _load(reset: true),
                      icon: const Icon(Icons.search),
                      label: const Text('Search'),
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
                  ? const _OrderCreateEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No items matched',
                      subtitle:
                          'Try a different code or name to search the two servers.',
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
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => Navigator.of(context).pop(item),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _ItemTag(
                                          icon: Icons.qr_code_2_outlined,
                                          label: item.itemCode.isEmpty
                                              ? 'No code'
                                              : item.itemCode,
                                        ),
                                        _ItemTag(
                                          icon: Icons.inventory_outlined,
                                          label: 'Total ${item.totalQuantity}',
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
