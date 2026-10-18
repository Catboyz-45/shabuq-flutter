import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The ShabuQ hot-pot logo (the same artwork as the app icon).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40});

  static const asset = 'assets/icon/icon.JPG';

  final double size;

  @override
  Widget build(BuildContext context) {
    // The artwork is a rounded square on white; clip just inside its edge so
    // the white corners never show on coloured backgrounds.
    return Semantics(
      label: 'ShabuQ',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.23),
        child: SizedBox.square(
          dimension: size,
          child: Transform.scale(
            scale: 1.06,
            child: Image.asset(asset, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

/// "Shabu" followed by the yellow Q ticket, optionally after the logo.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 26, this.color, this.showLogo = true});

  /// Height of the letters; the logo and Q chip scale with it.
  final double size;
  final Color? color;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: 'ShabuQ',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLogo) ...[
            BrandLogo(size: size * 1.45),
            SizedBox(width: size * 0.35),
          ],
          Text(
            'Shabu',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: size,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: textColor,
            ),
          ),
          SizedBox(width: size * 0.12),
          QChip(size: size * 1.08),
        ],
      ),
    );
  }
}

/// The yellow "Q" ticket used in the wordmark and the staff rail.
class QChip extends StatelessWidget {
  const QChip({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Palette.yolk,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Text(
        'Q',
        style: AppFonts.numbers(
          fontSize: size * 0.72,
          color: Palette.ink,
          height: 1,
        ),
      ),
    );
  }
}

/// A rounded label for states such as "open" or "4 waiting".
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.leading,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading used on customer screens.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
