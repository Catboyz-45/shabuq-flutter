import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shabuq_flutter/widgets/motion.dart';

/// Runs before every test file: no endless animations, and an in-memory
/// store for things the app remembers on the device.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Motion.loops = false;
  SharedPreferences.setMockInitialValues({});
  await testMain();
}
