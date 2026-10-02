import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Layout breakpoints shared by the app.
class Breakpoints {
  Breakpoints._();

  /// At or above this width the app shows a navigation rail instead of the
  /// bottom navigation bar (tablets, foldables, landscape phones).
  static const double rail = 600;

  /// At or above this width the navigation rail shows its labels.
  static const double extendedRail = 1000;

  /// Maximum width of reading/form content on large screens.
  static const double content = 840;

  static bool useRail(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= rail;
}

/// Centers [child] horizontally and caps its width at [maxWidth].
///
/// On screens narrower than [maxWidth] the child is returned unchanged, so
/// phone layouts are not affected. On wider screens the child gets the same
/// tight height and a narrower tight width, which keeps scroll views, forms
/// and `Expanded` children behaving exactly as they do on phones.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.content,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth ||
            constraints.maxWidth <= maxWidth) {
          return child;
        }
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: math.min(constraints.maxWidth, maxWidth),
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: child,
          ),
        );
      },
    );
  }
}
