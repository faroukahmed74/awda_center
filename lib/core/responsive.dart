import 'package:flutter/material.dart';

/// Breakpoints for responsive layout (works on Android, iOS, Web, macOS).
class Breakpoint {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;
  static bool isTabletOrWider(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobile;
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobile && w < desktop;
  }
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  /// Safe padding that respects notches, status bar, and keyboard.
  static EdgeInsets safePadding(BuildContext context) {
    return MediaQuery.paddingOf(context);
  }

  /// Whether to use a compact layout (phone portrait).
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile ||
      MediaQuery.sizeOf(context).height < 500;
}

class ResponsivePadding {
  static EdgeInsets all(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= Breakpoint.desktop) return const EdgeInsets.all(24);
    if (w >= Breakpoint.tablet) return const EdgeInsets.all(20);
    if (w >= Breakpoint.mobile) return const EdgeInsets.all(16);
    return const EdgeInsets.all(12);
  }

  static EdgeInsets horizontal(BuildContext context) {
    final e = all(context);
    return EdgeInsets.symmetric(horizontal: e.left);
  }

  static EdgeInsets vertical(BuildContext context) {
    final e = all(context);
    return EdgeInsets.symmetric(vertical: e.top);
  }
}

/// Max width for content (forms, cards) so layout doesn't stretch too much on desktop.
const double kMaxContentWidth = 800;
const double kMaxFormWidth = 480;

double responsiveMaxContentWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= Breakpoint.desktop) return kMaxContentWidth;
  return double.infinity;
}

double responsiveMaxFormWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= Breakpoint.mobile) return kMaxFormWidth;
  return double.infinity;
}

double responsiveLogoSize(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= Breakpoint.desktop) return 120;
  if (w >= Breakpoint.tablet) return 100;
  if (w >= Breakpoint.mobile) return 88;
  return 72;
}

double responsiveLogoSizeSmall(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= Breakpoint.desktop) return 40;
  if (w >= Breakpoint.mobile) return 36;
  return 32;
}

int responsiveCrossAxisCount(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= Breakpoint.desktop) return 3;
  if (w >= Breakpoint.tablet) return 2;
  return 1;
}

/// Wraps child with SafeArea and responsive padding for body content.
Widget responsiveBodyPadding(BuildContext context, {required Widget child}) {
  return SafeArea(
    child: Padding(
      padding: ResponsivePadding.all(context),
      child: child,
    ),
  );
}

/// Responsive list padding (for ListView.builder etc.).
EdgeInsets responsiveListPadding(BuildContext context) {
  return ResponsivePadding.all(context);
}
