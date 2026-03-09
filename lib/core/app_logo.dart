import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'responsive.dart';

/// In-app logo: light and dark assets. App icon (launcher) is unchanged and set in pubspec flutter_launcher_icons.
const String kAppLogoLightAsset = 'assets/AWDA Logo ( Light Mode ).png';
const String kAppLogoDarkAsset = 'assets/AWDA Logo White ( Dark Mode ).png';

/// Displays the app logo at a given size. Uses light or dark asset from current theme. Set [useResponsiveSize] to true to size from screen.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 96,
    this.fit = BoxFit.contain,
    this.useResponsiveSize = false,
  });

  final double size;
  final BoxFit fit;
  /// When true, ignores [size] and uses responsive size from context (for login/dashboard).
  final bool useResponsiveSize;

  @override
  Widget build(BuildContext context) {
    final s = useResponsiveSize ? responsiveLogoSize(context) : size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = isDark ? kAppLogoDarkAsset : kAppLogoLightAsset;
    return Image.asset(
      asset,
      width: s,
      height: s,
      fit: fit,
      errorBuilder: (_, __, ___) => Icon(Icons.medical_services, size: s, color: Theme.of(context).colorScheme.primary),
    );
  }
}

/// For login/splash: same app logo (PNG preferred), smaller size so it doesn’t dominate.
class LoginLogoHeader extends StatelessWidget {
  const LoginLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    final h = size.height;
    // Scale by width and cap by height so short screens (landscape, small devices) don't overflow.
    final byWidth = (w * 0.42).clamp(140.0, 280.0);
    final byHeight = (h * 0.28).clamp(120.0, 280.0);
    final height = byWidth > byHeight ? byHeight : byWidth;
    final isDark = theme.brightness == Brightness.dark;
    final asset = isDark ? kAppLogoDarkAsset : kAppLogoLightAsset;
    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.medical_services, size: height * 0.85, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).appTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
