import 'package:flutter/material.dart';

class FallbackNetworkImage extends StatefulWidget {
  const FallbackNetworkImage({
    super.key,
    required this.imageUrls,
    required this.iconColor,
    this.fit = BoxFit.cover,
    this.iconSize = 34,
  });

  final List<String> imageUrls;
  final Color iconColor;
  final BoxFit fit;
  final double iconSize;

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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openImagePreview(context, urls, index),
      child: Image.network(
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
      ),
    );
  }

  void _openImagePreview(
    BuildContext context,
    List<String> urls,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenImagePreview(
          imageUrls: urls,
          initialIndex: initialIndex,
        ),
      ),
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.imageUrls.length > 1
              ? '${_activeIndex + 1}/${widget.imageUrls.length}'
              : 'Image',
        ),
      ),
      body: SafeArea(
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
    );
  }
}
