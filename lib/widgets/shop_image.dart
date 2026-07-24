import 'package:flutter/material.dart';

class ShopImage extends StatelessWidget {
  const ShopImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (source.trim().isEmpty) {
      return _placeholder();
    }
    return Image(
      image:
          source.startsWith('https://')
              ? NetworkImage(source)
              : AssetImage(source),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Icon(Icons.storefront, size: 48, color: Colors.grey),
    );
  }
}
