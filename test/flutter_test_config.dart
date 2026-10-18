import 'dart:async';

import 'package:shabuq_flutter/theme/app_theme.dart';
import 'package:shabuq_flutter/widgets/motion.dart';

/// Runs before every test file: no font downloads and no endless animations.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppFonts.enabled = false;
  Motion.loops = false;
  await testMain();
}
