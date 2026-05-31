import 'package:flutter/material.dart';

const double kTabletBreakpoint = 600.0;

class ResponsiveLayout extends StatelessWidget {
  final Widget phone;
  final Widget tablet;

  const ResponsiveLayout({
    super.key,
    required this.phone,
    required this.tablet,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kTabletBreakpoint) {
          return tablet;
        }
        return phone;
      },
    );
  }
}
