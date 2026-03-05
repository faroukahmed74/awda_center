/// Helpers for patient date of birth: store as ISO date (yyyy-MM-dd) and compute age.

/// Returns date as ISO date string (yyyy-MM-dd) for storage.
String toIsoDateString(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Tries to parse [dateOfBirth] (e.g. ISO yyyy-MM-dd or legacy text) to [DateTime].
DateTime? parseDateOfBirth(String? dateOfBirth) {
  if (dateOfBirth == null || dateOfBirth.trim().isEmpty) return null;
  final s = dateOfBirth.trim();
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');
  final m = iso.firstMatch(s);
  if (m != null) {
    final y = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final d = int.tryParse(m.group(3)!);
    if (y != null && mo != null && d != null && mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
      return DateTime(y, mo, d);
    }
  }
  return DateTime.tryParse(s);
}

/// Returns age in years from [dateOfBirth] string, or null if unparseable.
int? ageFromDateOfBirth(String? dateOfBirth) {
  final d = parseDateOfBirth(dateOfBirth);
  if (d == null) return null;
  final now = DateTime.now();
  int age = now.year - d.year;
  if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
  return age < 0 ? null : age;
}
