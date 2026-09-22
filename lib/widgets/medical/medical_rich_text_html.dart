import 'dart:convert';

import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

/// Helpers for medical-detail rich text stored in Firestore string fields.
///
/// Preferred format: JSON `{"awdaRich":1,"ops":[...]}` (Quill Delta) so colors
/// round-trip. Legacy HTML / plain text still load.
class MedicalRichTextHtml {
  MedicalRichTextHtml._();

  static const richMarker = 'awdaRich';

  static final RegExp _tagPattern = RegExp(r'<[a-zA-Z/!][^>]*>');
  static final RegExp _hex8 = RegExp(
    r'^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{6})$',
  );

  static bool isLikelyHtml(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    if (isDeltaJson(value)) return false;
    return _tagPattern.hasMatch(value);
  }

  static bool isDeltaJson(String? value) {
    if (value == null) return false;
    final t = value.trim();
    if (!t.startsWith('{')) return false;
    try {
      final decoded = jsonDecode(t);
      return decoded is Map &&
          decoded[richMarker] == 1 &&
          decoded['ops'] is List;
    } catch (_) {
      return false;
    }
  }

  static bool isEmpty(String? value) {
    if (value == null) return true;
    if (isDeltaJson(value)) {
      try {
        final ops = deltaOpsFromStored(value);
        final html = deltaOpsToHtml(ops);
        return htmlToPlainText(html).trim().isEmpty;
      } catch (_) {
        return value.trim().isEmpty;
      }
    }
    return htmlToPlainText(value).trim().isEmpty;
  }

  /// Flutter Quill stores `#AARRGGBB`. Convert to `#RRGGBB` for CSS/HTML.
  static String? normalizeCssColor(String? color) {
    if (color == null || color.isEmpty) return color;
    final m = _hex8.firstMatch(color.trim());
    if (m != null) return '#${m.group(2)}';
    return color;
  }

  static Map<String, dynamic> normalizeDeltaOpColors(Map<String, dynamic> op) {
    final attrs = op['attributes'];
    if (attrs is! Map) return op;
    final map = Map<String, dynamic>.from(attrs);
    var changed = false;
    for (final key in ['color', 'background']) {
      final v = map[key];
      if (v is String) {
        final n = normalizeCssColor(v);
        if (n != null && n != v) {
          map[key] = n;
          changed = true;
        }
      }
    }
    if (!changed) return op;
    return {...op, 'attributes': map};
  }

  static List<Map<String, dynamic>> normalizeOps(List<dynamic> ops) {
    return [
      for (final op in ops)
        if (op is Map)
          normalizeDeltaOpColors(Map<String, dynamic>.from(op))
        else
          <String, dynamic>{},
    ];
  }

  /// Encode Quill Delta ops for Firestore (lossless for color/bold/etc.).
  static String encodeDeltaOps(List<dynamic> ops) {
    final normalized = normalizeOps(ops);
    return jsonEncode({richMarker: 1, 'ops': normalized});
  }

  static List<Map<String, dynamic>> deltaOpsFromStored(String stored) {
    final decoded = jsonDecode(stored.trim()) as Map<String, dynamic>;
    final ops = decoded['ops'];
    if (ops is! List) return [];
    return normalizeOps(ops);
  }

  static String deltaOpsToHtml(List<Map<String, dynamic>> ops) {
    if (ops.isEmpty) return '';
    return QuillDeltaToHtmlConverter(
      ops,
      ConverterOptions(
        sanitizerOptions: OpAttributeSanitizerOptions(
          allow8DigitHexColors: true,
        ),
        converterOptions: OpConverterOptions(
          inlineStylesFlag: true,
        ),
      ),
    ).convert().trim();
  }

  /// Move `style="..."` from bold/italic/underline tags onto an inner `<span>`,
  /// because HtmlToDelta ignores styles on those tags.
  static String prepareHtmlForImport(String html) {
    var s = html;
    // <strong style="color:#f00">text</strong> → <strong><span style="color:#f00">text</span></strong>
    s = s.replaceAllMapped(
      RegExp(
        r'<(strong|b|em|i|u|s|strike)([^>]*?)\sstyle="([^"]*)"([^>]*)>([\s\S]*?)</\1>',
        caseSensitive: false,
      ),
      (m) {
        final tag = m.group(1)!;
        final before = m.group(2) ?? '';
        final style = m.group(3)!;
        final after = m.group(4) ?? '';
        final inner = m.group(5) ?? '';
        return '<$tag$before$after><span style="$style">$inner</span></$tag>';
      },
    );
    return s;
  }

  static List<Map<String, dynamic>> htmlToDeltaOps(String html) {
    final prepared = prepareHtmlForImport(html);
    final delta = HtmlToDelta().convert(prepared);
    return normalizeOps(delta.toJson());
  }

  /// HTML suitable for [flutter_html] display (from any stored format).
  static String toDisplayHtml(String stored) {
    final t = stored.trim();
    if (t.isEmpty) return '';
    if (isDeltaJson(t)) {
      return deltaOpsToHtml(deltaOpsFromStored(t));
    }
    if (isLikelyHtml(t)) return t;
    // Plain text → escape + preserve newlines
    final escaped = t
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return escaped.split('\n').map((l) => '<p>$l</p>').join();
  }

  /// Strip tags / entities for PDF export and emptiness checks.
  static String htmlToPlainText(String input) {
    var s = input;
    if (isDeltaJson(s)) {
      s = toDisplayHtml(s);
    }
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
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }
}
