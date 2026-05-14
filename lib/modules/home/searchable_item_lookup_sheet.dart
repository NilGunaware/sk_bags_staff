import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/local_item_sync_service.dart';
import '../../core/services/permission_service.dart';
import '../../data/models/order_models.dart';
import '../../routes/app_routes.dart';
import 'fallback_network_image.dart';

class SearchableItemLookupSheet extends StatefulWidget {
  const SearchableItemLookupSheet({
    super.key,
    this.title = 'Search Item',
    this.subtitle = 'Search by item code or item name, or scan QR.',
  });

  final String title;
  final String subtitle;

  static const String cameraScanRequest = '__camera_scan_request__';

  static Future<String?> open(
    BuildContext context, {
    String title = 'Search Item',
    String subtitle = 'Search by item code or item name, or scan QR.',
  }) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          SearchableItemLookupSheet(title: title, subtitle: subtitle),
    );

    FocusManager.instance.primaryFocus?.unfocus();
    final normalized = normalizeLookupValue(value ?? '');
    if (normalized.isEmpty) {
      return null;
    }

    if (normalized == cameraScanRequest) {
      // Let the modal sheet finish removing its barrier before opening camera.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final scannedValue = await Get.toNamed(Routes.scanner);
      return normalizeLookupValue(scannedValue?.toString() ?? '');
    }

    return normalized;
  }

  static String normalizeLookupValue(String value) {
    return value.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '').trim();
  }

  @override
  State<SearchableItemLookupSheet> createState() =>
      _SearchableItemLookupSheetState();
}

class _SearchableItemLookupSheetState extends State<SearchableItemLookupSheet> {
  static const int _pageSize = 20;
  static const Duration _debounceDuration = Duration(milliseconds: 350);

  final LocalItemSyncService _itemSyncService =
      Get.find<LocalItemSyncService>();
  final TextEditingController _queryController = TextEditingController();
  final Map<String, MergedItemModel> _loadedItems = <String, MergedItemModel>{};

  Timer? _debounce;
  List<MergedItemModel> _items = const <MergedItemModel>[];
  List<String> _warnings = const <String>[];
  bool _isSearching = false;
  String? _message;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _queryController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _items = const <MergedItemModel>[];
        _warnings = const <String>[];
        _message = null;
        _isSearching = false;
      });
      return;
    }

    final localPage = _filterLocal(query);
    if (localPage.items.isNotEmpty) {
      setState(() {
        _items = localPage.items;
        _warnings = localPage.warnings;
        _message = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _items = const <MergedItemModel>[];
      _message = null;
    });
    _debounce = Timer(_debounceDuration, () => _searchRemote(query));
  }

  MergedItemPage _filterLocal(
    String query, {
    List<String> warnings = const [],
  }) {
    return _itemSyncService.filterLoadedItems(
      items: _loadedItems.values,
      page: 1,
      pageSize: _pageSize,
      query: query,
      warnings: warnings,
    );
  }

  Future<void> _searchRemote(String query) async {
    final token = ++_searchToken;
    setState(() {
      _isSearching = true;
      _message = null;
    });

    try {
      final page = await _itemSyncService.searchItems(
        page: 1,
        pageSize: _pageSize,
        query: query,
      );

      if (!mounted || token != _searchToken) {
        return;
      }

      for (final item in page.items) {
        _loadedItems[item.key] = item;
      }

      final localPage = _filterLocal(query, warnings: page.warnings);
      setState(() {
        _items = localPage.items.isNotEmpty ? localPage.items : page.items;
        _warnings = page.warnings;
        _message = _items.isEmpty ? 'No item found for "$query".' : null;
      });
    } catch (error) {
      if (!mounted || token != _searchToken) {
        return;
      }
      setState(() {
        _items = const <MergedItemModel>[];
        _warnings = const <String>[];
        _message = 'Unable to search item right now.';
      });
    } finally {
      if (mounted && token == _searchToken) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _scanWithCamera() async {
    final ok = await PermissionService.instance.ensureCameraPermission();
    if (!ok) {
      Get.snackbar(
        '',
        'Camera permission is required to scan QR code.',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(SearchableItemLookupSheet.cameraScanRequest);
  }

  void _submitTypedValue() {
    final typedValue = SearchableItemLookupSheet.normalizeLookupValue(
      _queryController.text,
    );
    if (typedValue.isEmpty) {
      return;
    }
    _complete(typedValue);
  }

  void _selectItem(MergedItemModel item) {
    final lookup = item.itemCode.trim().isNotEmpty
        ? item.itemCode
        : item.itemName;
    _complete(lookup);
  }

  void _complete(String value) {
    final normalized = SearchableItemLookupSheet.normalizeLookupValue(value);
    if (normalized.isEmpty) {
      return;
    }
    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: 0.86,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.subtitle,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _scanWithCamera,
                      icon: const Icon(Icons.qr_code_scanner_outlined),
                      label: const Text('Scan QR'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _queryController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _submitTypedValue(),
                    decoration: InputDecoration(
                      labelText: 'Item code or item name',
                      hintText: 'Type to search items',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _queryController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              onPressed: _queryController.clear,
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: const Color(0xFFF8F8F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isSearching
                              ? 'Searching both item servers...'
                              : 'Select an item from the dropdown, or search typed value directly.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _submitTypedValue,
                        child: const Text('Search Direct'),
                      ),
                    ],
                  ),
                  if (_isSearching) ...[
                    const SizedBox(height: 6),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  if (_warnings.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final warning in _warnings.take(2))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          warning,
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(child: _buildResults()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final query = _queryController.text.trim();
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            _message ??
                (query.isEmpty
                    ? 'Start typing an item code or item name.'
                    : 'Keep typing to search by item code or item name.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _LookupResultTile(item: item, onTap: () => _selectItem(item));
      },
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemCount: _items.length,
    );
  }
}

class _LookupResultTile extends StatelessWidget {
  const _LookupResultTile({required this.item, required this.onTap});

  final MergedItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F8F8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: FallbackNetworkImage(
                    imageUrls: item.imageUrls,
                    iconColor: AppColors.primary,
                    iconSize: 20,
                    enablePreview: false,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName.trim().isEmpty
                          ? 'No item name'
                          : item.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniChip(
                          icon: Icons.qr_code_2_outlined,
                          label: item.itemCode.trim().isEmpty
                              ? '-'
                              : item.itemCode,
                        ),
                        _MiniChip(
                          icon: Icons.shopping_bag_outlined,
                          label: '${item.totalQuantity} qty',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
