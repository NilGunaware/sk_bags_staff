import 'package:flutter/material.dart';

class FallbackNetworkImage extends StatefulWidget {
  const FallbackNetworkImage({
    super.key,
    required this.imageUrls,
    required this.iconColor,
    this.fit = BoxFit.cover,
    this.iconSize = 34,
    this.enablePreview = true,
  });

  final List<String> imageUrls;
  final Color iconColor;
  final BoxFit fit;
  final double iconSize;
  final bool enablePreview;

  @override
  State<FallbackNetworkImage> createState() => _FallbackNetworkImageState();
}

class _FallbackNetworkImageState extends State<FallbackNetworkImage> {
  int _activeIndex = 0;

  List<String> get _urls {
    final seen = <String>{};
    return widget.imageUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty && seen.add(url))
        .toList();
  }

  @override
  void didUpdateWidget(covariant FallbackNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls.join('|') != widget.imageUrls.join('|')) {
      _activeIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    if (urls.isEmpty) {
      return _emptyIcon();
    }

    final index = _activeIndex.clamp(0, urls.length).toInt();
    if (index >= urls.length) {
      return _emptyIcon();
    }

    final image = Image.network(
      urls[index],
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _activeIndex != index) {
            return;
          }
          setState(
            () => _activeIndex = index < urls.length - 1
                ? index + 1
                : urls.length,
          );
        });
        return _emptyIcon();
      },
    );

    if (!widget.enablePreview) {
      return image;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openImagePreview(context, urls, index),
      child: image,
    );
  }

  void _openImagePreview(
    BuildContext context,
    List<String> urls,
    int initialIndex,
  ) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close image preview',
      barrierColor: Colors.black,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _FullScreenImagePreview(
          imageUrls: urls,
          initialIndex: initialIndex,
        );
      },
    );
  }

  Widget _emptyIcon() {
    return Icon(
      Icons.image_not_supported_outlined,
      color: widget.iconColor,
      size: widget.iconSize,
    );
  }
}

class _FullScreenImagePreview extends StatefulWidget {
  const _FullScreenImagePreview({
    required this.imageUrls,
    required this.initialIndex,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<_FullScreenImagePreview> createState() =>
      _FullScreenImagePreviewState();
}

class _FullScreenImagePreviewState extends State<_FullScreenImagePreview> {
  late final PageController _pageController;
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _activeIndex = index),
                itemCount: widget.imageUrls.length,
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: Image.network(
                        widget.imageUrls[index],
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.white70,
                                size: 54,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Image not available',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Material(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: _closePreview,
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Close',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.imageUrls.length > 1
                        ? '${_activeIndex + 1}/${widget.imageUrls.length}'
                        : 'Image Preview',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: SafeArea(
              top: false,
              child: ElevatedButton.icon(
                onPressed: _closePreview,
                icon: const Icon(Icons.close),
                label: const Text('Close Preview'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _closePreview() {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
