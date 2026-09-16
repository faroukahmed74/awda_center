/// Helpers for medical-detail rich text stored as a small HTML subset in Firestore.
class MedicalRichTextHtml {
  MedicalRichTextHtml._();

  static final RegExp _tagPattern = RegExp(r'<[a-zA-Z/!][^>]*>');

  static bool isLikelyHtml(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return _tagPattern.hasMatch(value);
  }

  static bool isEmpty(String? value) {
    if (value == null) return true;
    final plain = htmlToPlainText(value).trim();
    return plain.isEmpty;
  }

  /// Strip tags / entities for PDF export and emptiness checks.
  static String htmlToPlainText(String input) {
    var s = input;
    // Common block breaks → newlines
    s = s.replaceAll(
      RegExp(r'</(p|div|h[1-6]|li|tr|blockquote)>', caseSensitive: false),
      '\n',
    );
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    s = s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    // Collapse excessive blank lines
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }
}
