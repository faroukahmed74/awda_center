import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'responsive.dart';

/// App logo: prefer PNG (transparent, shape only). Fallback to JPG if PNG is missing.
const String kAppLogoAsset = 'assets/CenterLogo.png';
const String _kAppLogoFallbackAsset = 'assets/CenterLogo.jpg';

/// Displays the app logo at a given size. Set [useResponsiveSize] to true to size from screen.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 48,
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
    return Image.asset(
      kAppLogoAsset,
      width: s,
      height: s,
      fit: fit,
      errorBuilder: (_, __, ___) => Image.asset(
        _kAppLogoFallbackAsset,
        width: s,
        height: s,
        fit: fit,
        errorBuilder: (_, __, ___) => Icon(Icons.medical_services, size: s, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

/// For login/splash: same app logo (PNG preferred), smaller size so it doesn’t dominate.
class LoginLogoHeader extends StatelessWidget {
  const LoginLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final height = (w * 0.26).clamp(100.0, 160.0);
    return Image.asset(
      kAppLogoAsset,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Image.asset(
        _kAppLogoFallbackAsset,
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
      ),
    );
  }
}
