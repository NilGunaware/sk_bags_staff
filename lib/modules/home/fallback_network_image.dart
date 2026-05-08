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

    final index = _activeIndex.clamp(0, urls.length - 1);
    return Image.network(
      urls[index],
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        if (index < urls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _activeIndex == index) {
              setState(() => _activeIndex = index + 1);
            }
          });
          return _emptyIcon();
        }
        return _emptyIcon();
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
