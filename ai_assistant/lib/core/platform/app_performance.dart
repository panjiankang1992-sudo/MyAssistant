import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppPerformance {
  const AppPerformance._();

  static bool get isOhos => defaultTargetPlatform.name.toLowerCase() == 'ohos';

  static bool get lowLatencyMode => isOhos;

  static bool shouldReduceMotion(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return lowLatencyMode || (mediaQuery?.disableAnimations ?? false);
  }

  static Duration animationDuration(
    BuildContext context,
    Duration normal, {
    Duration reduced = Duration.zero,
  }) {
    return shouldReduceMotion(context) ? reduced : normal;
  }
}
