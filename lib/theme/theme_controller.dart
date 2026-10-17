import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's light/dark/system choice, remembered on the device.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._(super.value, this._preferences);

  static const _key = 'themeMode';

  final SharedPreferences? _preferences;

  static Future<ThemeController> load() async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } on Exception {
      // Storage can be unavailable (e.g. a private browser window); fall
      // back to following the system without remembering the choice.
    }
    final stored = preferences?.getString(_key);
    final mode = ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
    return ThemeController._(mode, preferences);
  }

  /// For tests and previews: starts from [mode] and stores nothing.
  ThemeController.memory([ThemeMode mode = ThemeMode.system])
    : this._(mode, null);

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    await _preferences?.setString(_key, mode.name);
  }
}

/// Makes the [ThemeController] available to the widget tree.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()!.notifier!;
}
