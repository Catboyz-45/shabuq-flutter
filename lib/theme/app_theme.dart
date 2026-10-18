import 'package:flutter/material.dart';

/// ShabuQ's colours: chilli red and egg-yolk yellow, like a paper queue
/// ticket, on warm off-white (customers) or near-black (shop staff).
abstract final class Palette {
  static const chili = Color(0xFFC8341A);
  static const chiliDark = Color(0xFF8F2410);
  static const chiliTint = Color(0xFFFBE9E4);
  static const chiliSoft = Color(0xFFFF8A70);
  static const yolk = Color(0xFFFFC531);
  static const yolkDeep = Color(0xFFE0A817);
  static const yolkTint = Color(0xFFFFF4D1);
  static const ink = Color(0xFF1A1714);
  static const inkSoft = Color(0xFF4A443E);
  static const muted = Color(0xFF6B645C);
  static const ground = Color(0xFFF7F6F3);
  static const line = Color(0xFFECE8E1);
  static const lineStrong = Color(0xFFE2DDD5);
  static const leaf = Color(0xFF1F7A4D);
  static const leafTint = Color(0xFFE2F2E8);
  static const leafInk = Color(0xFF17603C);

  static const night = Color(0xFF141210);
  static const nightPanel = Color(0xFF1F1C19);
  static const nightCard = Color(0xFF2A2622);
  static const nightLine = Color(0xFF3A3530);
  static const paper = Color(0xFFF4F1EC);
  static const ash = Color(0xFFB5AEA5);
  static const ember = Color(0xFFFF8A5B);
  static const mint = Color(0xFF5BD49A);
}

/// Kept for code that only needs "the brand colour".
const brandColor = Palette.chili;

/// Anuphan for all text and Chakra Petch for queue numbers, codes and
/// timers. Both are bundled in assets/fonts, so they work offline.
abstract final class AppFonts {
  static const body = 'Anuphan';
  static const display = 'ChakraPetch';

  /// The squared "queue display" face for numbers.
  static TextStyle numbers({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: display,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}

/// All app colours come from here so light and dark mode stay consistent.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Palette.chili,
    onPrimary: Colors.white,
    primaryContainer: Palette.chiliTint,
    onPrimaryContainer: Palette.chiliDark,
    secondary: Palette.yolk,
    onSecondary: Palette.ink,
    secondaryContainer: Palette.yolkTint,
    onSecondaryContainer: Color(0xFF4A3600),
    tertiary: Palette.leaf,
    onTertiary: Colors.white,
    tertiaryContainer: Palette.leafTint,
    onTertiaryContainer: Palette.leafInk,
    error: Color(0xFFA12A14),
    onError: Colors.white,
    errorContainer: Palette.chiliTint,
    onErrorContainer: Palette.chiliDark,
    surface: Palette.ground,
    onSurface: Palette.ink,
    onSurfaceVariant: Palette.muted,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Colors.white,
    surfaceContainer: Color(0xFFF0EEEA),
    surfaceContainerHigh: Palette.line,
    surfaceContainerHighest: Palette.lineStrong,
    outline: Color(0xFF8F877E),
    outlineVariant: Palette.lineStrong,
    inverseSurface: Palette.ink,
    onInverseSurface: Palette.paper,
    inversePrimary: Palette.yolk,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Palette.yolk,
    onPrimary: Palette.night,
    primaryContainer: Color(0xFF3A2A10),
    onPrimaryContainer: Color(0xFFFFD27A),
    secondary: Palette.ember,
    onSecondary: Palette.night,
    secondaryContainer: Color(0xFF4A2018),
    onSecondaryContainer: Color(0xFFFFD9CF),
    tertiary: Palette.mint,
    onTertiary: Color(0xFF0E2A1C),
    tertiaryContainer: Color(0xFF17382A),
    onTertiaryContainer: Color(0xFF7FE0AE),
    error: Palette.chiliSoft,
    onError: Palette.night,
    errorContainer: Color(0xFF4A2018),
    onErrorContainer: Color(0xFFFFD9CF),
    surface: Palette.night,
    onSurface: Palette.paper,
    onSurfaceVariant: Palette.ash,
    surfaceContainerLowest: Color(0xFF0E0C0B),
    surfaceContainerLow: Palette.nightPanel,
    surfaceContainer: Palette.nightPanel,
    surfaceContainerHigh: Palette.nightCard,
    surfaceContainerHighest: Palette.nightLine,
    outline: Color(0xFF8F877E),
    outlineVariant: Palette.nightLine,
    inverseSurface: Palette.paper,
    onInverseSurface: Palette.ink,
    inversePrimary: Palette.chili,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = isLight ? _lightScheme : _darkScheme;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppFonts.body,
    );
    final text = base.textTheme;
    final cardColor = isLight ? Colors.white : Palette.nightPanel;
    final fieldColor = isLight ? Colors.white : Palette.nightCard;
    final label = text.labelLarge!.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    final rounded16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    OutlineInputBorder fieldBorder(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: 1.5),
    );

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge!.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: rounded16,
          textStyle: label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: rounded16,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
          textStyle: label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          textStyle: label.copyWith(fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: fieldBorder(scheme.outlineVariant),
        enabledBorder: fieldBorder(scheme.outlineVariant),
        focusedBorder: fieldBorder(scheme.onSurface),
        errorBorder: fieldBorder(scheme.error),
        focusedErrorBorder: fieldBorder(scheme.error),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainer,
        labelStyle: text.labelLarge!.copyWith(color: scheme.onSurface),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyLarge!.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.surfaceContainerHigh,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: text.labelMedium!.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: text.labelMedium!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? Colors.white : Palette.nightPanel,
        indicatorColor: scheme.surfaceContainerHigh,
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

  /// "You're next" and other heads-up states.
  final Color next;

  /// The shop has called the queue.
  final Color called;

  /// Seated and eating.
  final Color serving;
  final Color success;

  static const light = StatusColors(
    next: Color(0xFF8A5A00),
    called: Palette.chili,
    serving: Palette.leaf,
    success: Palette.leaf,
  );

  static const dark = StatusColors(
    next: Palette.yolk,
    called: Palette.ember,
    serving: Palette.mint,
    success: Palette.mint,
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
