import 'package:flutter/material.dart';

/// Centralized directional icons ensuring correct RTL/LTR mirroring across the app.
class AppIcons {
  AppIcons._();

  /// Returns true if the ambient direction is RTL.
  static bool isRtl(BuildContext context) {
    return Directionality.maybeOf(context) == TextDirection.rtl;
  }

  /// Trailing chevron for navigation into detail screens (points Left in RTL, Right in LTR).
  static IconData chevronForward(BuildContext context) {
    return isRtl(context) ? Icons.chevron_left_rounded : Icons.chevron_right_rounded;
  }

  /// Back chevron for popping navigation (points Right in RTL, Left in LTR).
  static IconData chevronBack(BuildContext context) {
    return isRtl(context) ? Icons.chevron_right_rounded : Icons.chevron_left_rounded;
  }

  /// Forward arrow for steps, send, or next actions (points Left in RTL, Right in LTR).
  static IconData arrowForward(BuildContext context) {
    return isRtl(context) ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded;
  }

  /// Back arrow for returning to previous screens (points Right in RTL, Left in LTR).
  static IconData arrowBack(BuildContext context) {
    return isRtl(context) ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded;
  }
}
