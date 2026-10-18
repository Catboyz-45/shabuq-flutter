import 'package:flutter/material.dart';

import '../utils/image_source.dart';

class ShopImage extends StatelessWidget {
  const ShopImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.storefront,
  });

  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final value = source.trim();
    if (value.isEmpty || !isAllowedImageSource(value)) {
      return _placeholder(Theme.of(context).colorScheme);
    }
    final scheme = Theme.of(context).colorScheme;
    return Image(
      image:
          value.startsWith('https://')
              ? NetworkImage(value)
              : AssetImage(value) as ImageProvider,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder:
          (context, child, progress) =>
              progress == null ? child : _placeholder(scheme, loading: true),
      errorBuilder: (_, _, _) => _placeholder(scheme),
    );
  }

  Widget _placeholder(ColorScheme scheme, {bool loading = false}) {
    final size = height != null && height!.isFinite ? height! : 96.0;
    return Container(
      width: width,
      height: height,
      color: scheme.surfaceContainer,
      alignment: Alignment.center,
      child:
          loading
              ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Icon(
                placeholderIcon,
                size: (size / 2).clamp(16, 48),
                color: scheme.onSurfaceVariant,
              ),
    );
  }
}
