import 'dart:async';

import 'package:shabuq_flutter/widgets/motion.dart';

/// Runs before every test file: no endless animations.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Motion.loops = false;
  await testMain();
}
