import 'package:intl/intl.dart';

/// App-wide date formats: Day / Month / Year (dd/MM/yyyy).
/// Use these instead of DateFormat.yMd() so all dates show consistently.
class AppDateFormat {
  AppDateFormat._();

  /// Short date: 23/02/2026
  static DateFormat get shortDate => DateFormat('dd/MM/yyyy');

  /// Same pattern as [shortDate] with locale (e.g. Arabic-Indic digits for `ar`).
  static DateFormat shortDateWithLocale(String locale) => DateFormat('dd/MM/yyyy', locale);

  /// Safe for filenames: 23-02-2026 (day-first, no slashes).
  static DateFormat get fileNameDate => DateFormat('dd-MM-yyyy');

  /// Date and time: 23/02/2026 14:30
  static DateFormat get shortDateTime => DateFormat('dd/MM/yyyy HH:mm');

  /// Time only (24h): 14:30
  static DateFormat shortTime([String? locale]) => DateFormat('HH:mm', locale ?? 'en');

  /// Short weekday: Mon
  static DateFormat shortWeekday([String? locale]) => DateFormat('EEE', locale ?? 'en');

  /// Date and time with seconds: 23/02/2026 14:30:45
  static DateFormat get shortDateTimeSec => DateFormat('dd/MM/yyyy HH:mm:ss');

  /// Medium (with month name): 23 Feb 2026. Pass locale e.g. 'en' or 'ar'.
  static DateFormat mediumDate([String? locale]) => DateFormat('dd MMM yyyy', locale ?? 'en');

  /// Month and year: Feb 2026
  static DateFormat monthYear([String? locale]) => DateFormat('MMM yyyy', locale ?? 'en');

  /// Month name only: February
  static DateFormat monthName([String? locale]) => DateFormat('MMMM', locale ?? 'en');

  /// Year only: 2026
  static DateFormat get yearOnly => DateFormat('yyyy');
}
