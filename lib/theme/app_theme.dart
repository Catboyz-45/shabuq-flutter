import 'package:flutter/material.dart';

/// ShabuQ's lavender brand colour, used as the seed for both themes.
const brandColor = Color(0xFF9590F8);

/// All app colours come from here so light and dark mode stay consistent.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: brightness,
    );
    final isLight = brightness == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: isLight ? brandColor : scheme.surfaceContainerHigh,
        foregroundColor: isLight ? Colors.white : scheme.onSurface,
      ),
      extensions: [isLight ? StatusColors.light : StatusColors.dark],
    );
  }
}

/// Colours for queue states, tuned for contrast in each brightness.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.next,
    required this.called,
    required this.serving,
    required this.success,
  });

  final Color next;
  final Color called;
  final Color serving;
  final Color success;

  static const light = StatusColors(
    next: Color(0xFFB45309),
    called: Color(0xFF15803D),
    serving: Color(0xFF0F766E),
    success: Color(0xFF15803D),
  );

  static const dark = StatusColors(
    next: Color(0xFFFBBF24),
    called: Color(0xFF4ADE80),
    serving: Color(0xFF2DD4BF),
    success: Color(0xFF4ADE80),
  );

  static StatusColors of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>() ?? light;

  @override
  StatusColors copyWith({
    Color? next,
    Color? called,
    Color? serving,
    Color? success,
  }) {
    return StatusColors(
      next: next ?? this.next,
      called: called ?? this.called,
      serving: serving ?? this.serving,
      success: success ?? this.success,
    );
  }

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      next: Color.lerp(next, other.next, t)!,
      called: Color.lerp(called, other.called, t)!,
      serving: Color.lerp(serving, other.serving, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

/// Style for buttons that delete or close something.
ButtonStyle destructiveButtonStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    backgroundColor: scheme.error,
    foregroundColor: scheme.onError,
  );
}
