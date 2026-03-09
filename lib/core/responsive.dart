import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Breakpoints for responsive layout (works on Android, iOS, Web, macOS).
class Breakpoint {
  /// Very small phones (e.g. 320–360px width).
  static const double xs = 360;
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
  static bool isExtraSmall(BuildContext context) =>
      MediaQuery.sizeOf(context).width < xs;

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
    if (w >= Breakpoint.xs) return const EdgeInsets.all(12);
    return const EdgeInsets.all(10);
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
  final size = MediaQuery.sizeOf(context);
  final w = size.width;
  final h = size.height;
  if (w >= Breakpoint.desktop) return 200;
  if (w >= Breakpoint.tablet) return 180;
  if (w >= Breakpoint.mobile) return 144;
  // Small phones: cap by height so short screens (e.g. landscape) don't overflow.
  if (w < Breakpoint.xs) return (h * 0.2).clamp(64.0, 96.0);
  final byHeight = (h * 0.22).clamp(72.0, 128.0);
  return byHeight;
}

/// Logo for app bar and drawer. Scales by viewport on all platforms.
double responsiveLogoSizeSmall(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final w = size.width;
  final h = size.height;
  // Extra-small phones: keep logo small so app bar and drawer fit.
  if (w < Breakpoint.xs) {
    return 52;
  }
  if (w >= Breakpoint.desktop) return kIsWeb ? 128 : 96;
  if (w >= Breakpoint.tablet) return kIsWeb ? 116 : 88;
  if (w >= Breakpoint.mobile) return kIsWeb ? 104 : 80;
  // Mobile portrait: cap by height so drawer header fits on short screens.
  final byWidth = 72.0;
  final drawerSafeHeight = (h * 0.18).clamp(48.0, 88.0);
  return byWidth > drawerSafeHeight ? drawerSafeHeight : byWidth;
}

/// Max height for drawer header content (logo + name + role). Use with drawer so it fits on all devices.
double responsiveDrawerHeaderLogoSize(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final h = size.height;
  // Drawer header should leave room for name + role; cap logo by height on short screens.
  final maxLogoByHeight = (h * 0.2).clamp(48.0, 96.0);
  final byWidth = responsiveLogoSizeSmall(context);
  return byWidth > maxLogoByHeight ? maxLogoByHeight : byWidth;
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
