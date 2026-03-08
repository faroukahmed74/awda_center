/// Minimal Arabic reshaper for PDF: converts basic Arabic (U+0600 block) to
/// presentation forms (U+FE70 block) so letters connect correctly in PDFs.
/// Used when arabic_reshaper package is not available (requires Dart 3.10+).

class ArabicPdfReshaper {
  ArabicPdfReshaper._();

  /// [isolated, final, initial, medial] for joining letters; [isolated, final] for non-joining.
  static const Map<int, List<int>> _forms = {
    0x0627: [0xFE8D, 0xFE8E], // alef
    0x0628: [0xFE8F, 0xFE90, 0xFE91, 0xFE92], // ba
    0x062A: [0xFE95, 0xFE96, 0xFE97, 0xFE98], // ta
    0x062B: [0xFE99, 0xFE9A, 0xFE9B, 0xFE9C], // tha
    0x062C: [0xFE9D, 0xFE9E, 0xFE9F, 0xFEA0], // jim
    0x062D: [0xFEA1, 0xFEA2, 0xFEA3, 0xFEA4], // ha
    0x062E: [0xFEA5, 0xFEA6, 0xFEA7, 0xFEA8], // kha
    0x062F: [0xFEA9, 0xFEAA], // dal
    0x0630: [0xFEAB, 0xFEAC], // thal
    0x0631: [0xFEAD, 0xFEAE], // ra
    0x0632: [0xFEAF, 0xFEB0], // zay
    0x0633: [0xFEB1, 0xFEB2, 0xFEB3, 0xFEB4], // sin
    0x0634: [0xFEB5, 0xFEB6, 0xFEB7, 0xFEB8], // shin
    0x0635: [0xFEB9, 0xFEBA, 0xFEBB, 0xFEBC], // sad
    0x0636: [0xFEBD, 0xFEBE, 0xFEBF, 0xFEC0], // dad
    0x0637: [0xFEC1, 0xFEC2, 0xFEC3, 0xFEC4], // ta
    0x0638: [0xFEC5, 0xFEC6, 0xFEC7, 0xFEC8], // za
    0x0639: [0xFEC9, 0xFECA, 0xFECB, 0xFECC], // ain
    0x063A: [0xFECD, 0xFECE, 0xFECF, 0xFED0], // ghain
    0x0641: [0xFED1, 0xFED2, 0xFED3, 0xFED4], // fa
    0x0642: [0xFED5, 0xFED6, 0xFED7, 0xFED8], // qaf
    0x0643: [0xFED9, 0xFEDA, 0xFEDB, 0xFEDC], // kaf
    0x0644: [0xFEDD, 0xFEDE, 0xFEDF, 0xFEE0], // lam
    0x0645: [0xFEE1, 0xFEE2, 0xFEE3, 0xFEE4], // mim
    0x0646: [0xFEE5, 0xFEE6, 0xFEE7, 0xFEE8], // nun
    0x0647: [0xFEE9, 0xFEEA, 0xFEEB, 0xFEEC], // ha
    0x0648: [0xFEED, 0xFEEE], // waw
    0x064A: [0xFEF1, 0xFEF2, 0xFEF3, 0xFEF4], // ya
    0x0622: [0xFE81, 0xFE82], // alef madda
    0x0629: [0xFE93, 0xFE94], // ta marbuta
    0x0649: [0xFEEF, 0xFEF0], // alef maqsura
  };

  static bool _connectsBefore(int code) =>
      code != 0x0627 && code != 0x062F && code != 0x0630 &&
      code != 0x0631 && code != 0x0632 && code != 0x0648 && code != 0x0622;

  static bool _connectsAfter(int code) =>
      code != 0x0627 && code != 0x062D && code != 0x062E && code != 0x062F &&
      code != 0x0630 && code != 0x0631 && code != 0x0632 && code != 0x0648 &&
      code != 0x0622 && code != 0x0629 && code != 0x0649;

  /// Reshape Arabic text so letters use correct contextual forms for PDF.
  static String reshape(String text) {
    if (text.isEmpty) return text;
    final runes = text.runes.toList();
    final out = StringBuffer();
    for (var i = 0; i < runes.length; i++) {
      final code = runes[i];
      final forms = _forms[code];
      if (forms == null) {
        out.writeCharCode(code);
        continue;
      }
      final prevArabic = i > 0 ? _forms.containsKey(runes[i - 1]) : false;
      final nextArabic = i < runes.length - 1 ? _forms.containsKey(runes[i + 1]) : false;
      final connectsBefore = prevArabic && _connectsAfter(runes[i - 1]);
      final connectsAfter = nextArabic && _connectsBefore(runes[i + 1]);
      int form;
      if (forms.length == 2) {
        form = connectsBefore ? forms[1] : forms[0]; // final : isolated
      } else {
        if (connectsBefore && connectsAfter) form = forms[3]; // medial
        else if (connectsBefore) form = forms[1]; // final
        else if (connectsAfter) form = forms[2]; // initial
        else form = forms[0]; // isolated
      }
      out.writeCharCode(form);
    }
    return out.toString();
  }

  static bool _isArabic(int code) =>
      (code >= 0x0600 && code <= 0x06FF) || _forms.containsKey(code);

  /// Whether the string contains Arabic characters that need reshaping.
  static bool hasArabic(String text) {
    for (final code in text.runes) {
      if (_isArabic(code)) return true;
    }
    return false;
  }
}
