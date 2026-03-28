import 'dart:async';

import 'package:flutter/material.dart';

import '../core/date_format.dart';
import '../core/responsive.dart';
import '../l10n/app_localizations.dart';

/// Live-updating date and time for the dashboard home screen.
/// Responsive: compact column on narrow viewports, split layout on tablet+.
/// Timer: **every second** on large viewports ([Breakpoint.tablet] and wider),
/// **every 30 seconds** on smaller screens (saves battery on phones).
class LiveDateTimeBanner extends StatefulWidget {
  const LiveDateTimeBanner({super.key});

  @override
  State<LiveDateTimeBanner> createState() => _LiveDateTimeBannerState();
}

class _LiveDateTimeBannerState extends State<LiveDateTimeBanner> with WidgetsBindingObserver {
  Timer? _timer;
  int? _lastIntervalSecs;

  static const _tickLarge = 1;
  static const _tickSmall = 30;

  bool _isLargeScreen(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= Breakpoint.tablet;

  void _restartTimerIfNeeded() {
    if (!mounted) return;
    final secs = _isLargeScreen(context) ? _tickLarge : _tickSmall;
    if (_lastIntervalSecs == secs && _timer != null) return;
    _lastIntervalSecs = secs;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: secs), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restartTimerIfNeeded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _restartTimerIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final loc = l10n.isArabic ? 'ar' : 'en';
    final now = DateTime.now();
    final dateStr = AppDateFormat.shortDateWithLocale(loc).format(now);
    final timeStr = AppDateFormat.shortTime(loc).format(now);
    final weekdayStr = AppDateFormat.shortWeekday(loc).format(now);

    final w = MediaQuery.sizeOf(context).width;
    final compact = w < Breakpoint.mobile || Breakpoint.isCompact(context);

    final timeStyle = (compact ? theme.textTheme.headlineSmall : theme.textTheme.displaySmall)?.copyWith(
      fontWeight: FontWeight.w600,
      color: cs.onSurface,
      height: 1.05,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final dateStyle = theme.textTheme.titleMedium?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );

    final weekdayStyle = theme.textTheme.labelLarge?.copyWith(
      color: cs.primary,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );

    final card = Card(
      elevation: 0,
      color: Color.alphaBlend(
        cs.primary.withValues(alpha: theme.brightness == Brightness.dark ? 0.14 : 0.08),
        cs.surfaceContainerHighest,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 22,
          vertical: compact ? 14 : 18,
        ),
        child: compact
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.schedule_rounded, size: 26, color: cs.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(weekdayStr, style: weekdayStyle),
                        const SizedBox(height: 2),
                        Text(dateStr, style: dateStyle),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(timeStr, style: timeStyle),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Icon(Icons.calendar_month_rounded, size: 32, color: cs.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(weekdayStr, style: weekdayStyle),
                        const SizedBox(height: 4),
                        Text(dateStr, style: dateStyle),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(timeStr, style: timeStyle),
                    ),
                  ),
                ],
              ),
      ),
    );

    return Semantics(
      label: '$weekdayStr, $dateStr $timeStr',
      child: card,
    );
  }
}
