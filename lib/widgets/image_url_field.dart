import 'package:flutter/material.dart';

import '../utils/image_source.dart';
import 'shop_image.dart';

/// Text field for an image link with a live preview, so admins can add
/// shop, menu and banner images without changing the app.
class ImageUrlField extends StatefulWidget {
  const ImageUrlField({
    super.key,
    required this.controller,
    this.label = 'ลิงก์รูปภาพ (ไม่บังคับ)',
    this.previewHeight = 120,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final double previewHeight;
  final bool enabled;

  @override
  State<ImageUrlField> createState() => _ImageUrlFieldState();
}

class _ImageUrlFieldState extends State<ImageUrlField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant ImageUrlField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text.trim();
    final error = imageSourceError(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'https://…',
            helperText: 'คัดลอกลิงก์รูปจากเว็บ แล้ววางที่นี่',
            errorText: error,
            border: const OutlineInputBorder(),
            suffixIcon:
                value.isEmpty
                    ? null
                    : IconButton(
                      tooltip: 'ล้างลิงก์',
                      onPressed: widget.controller.clear,
                      icon: const Icon(Icons.clear),
                    ),
          ),
        ),
        if (value.isNotEmpty && error == null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            // No explicit width: the stretched Column sizes it, and dialogs
            // that measure intrinsic width (AlertDialog) don't get infinity.
            child: SizedBox(
              height: widget.previewHeight,
              child: ShopImage(key: ValueKey(value), source: value),
            ),
          ),
        ],
      ],
    );
  }
}
