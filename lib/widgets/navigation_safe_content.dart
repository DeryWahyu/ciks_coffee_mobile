import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Centers short states above the floating navigation and lets taller ones scroll.
class NavigationSafeContent extends StatelessWidget {
  const NavigationSafeContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final bottom = MediaQuery.paddingOf(context).bottom;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - bottom - 48),
          ),
          child: Center(child: child),
        ),
      );
    },
  );
}
