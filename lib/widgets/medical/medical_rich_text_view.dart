import 'package:flutter/material.dart';

import 'medical_rich_text_html.dart';

/// Renders medical-detail rich text (Delta JSON, HTML, or plain).
///
/// Uses Quill Delta → [TextSpan] so inline colors are reliable (flutter_html
/// often loses `style="color"` on `<strong>`).
class MedicalRichTextView extends StatelessWidget {
  const MedicalRichTextView({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.bodyStyle,
    this.labelColor,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? bodyStyle;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final resolvedLabel = (labelStyle ??
            theme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: (theme.titleSmall?.fontSize ?? 14) + 7,
            ))
        ?.copyWith(color: labelColor ?? labelStyle?.color);
    final resolvedBody = bodyStyle ?? theme.bodyMedium ?? const TextStyle();

    final isRich = MedicalRichTextHtml.isDeltaJson(value) ||
        MedicalRichTextHtml.isLikelyHtml(value);

    if (!isRich) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$label: ', style: resolvedLabel),
              TextSpan(text: value, style: resolvedBody),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: resolvedLabel),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: resolvedBody,
              children: _spansFromStored(value, resolvedBody),
            ),
          ),
        ],
      ),
    );
  }

  static List<InlineSpan> _spansFromStored(String stored, TextStyle base) {
    try {
      final List<Map<String, dynamic>> ops;
      if (MedicalRichTextHtml.isDeltaJson(stored)) {
        ops = MedicalRichTextHtml.deltaOpsFromStored(stored);
      } else {
        ops = MedicalRichTextHtml.htmlToDeltaOps(stored);
      }
      return _spansFromOps(ops, base);
    } catch (_) {
      return [
        TextSpan(
          text: MedicalRichTextHtml.htmlToPlainText(stored),
          style: base,
        ),
      ];
    }
  }

  static List<InlineSpan> _spansFromOps(
    List<Map<String, dynamic>> ops,
    TextStyle base,
  ) {
    final spans = <InlineSpan>[];
    for (final op in ops) {
      final insert = op['insert'];
      if (insert is! String || insert.isEmpty) continue;

      final attrs = op['attributes'];
      var style = base;
      if (attrs is Map) {
        if (attrs['bold'] == true) {
          style = style.copyWith(fontWeight: FontWeight.bold);
        }
        if (attrs['italic'] == true) {
          style = style.copyWith(fontStyle: FontStyle.italic);
        }
        if (attrs['underline'] == true) {
          style = style.copyWith(decoration: TextDecoration.underline);
        }
        if (attrs['strike'] == true) {
          style = style.copyWith(decoration: TextDecoration.lineThrough);
        }

        final colorRaw = attrs['color'];
        if (colorRaw is String) {
          final parsed = _parseCssColor(
            MedicalRichTextHtml.normalizeCssColor(colorRaw) ?? colorRaw,
          );
          if (parsed != null) {
            style = style.copyWith(color: parsed);
          }
        }

        final bgRaw = attrs['background'];
        if (bgRaw is String) {
          final parsed = _parseCssColor(
            MedicalRichTextHtml.normalizeCssColor(bgRaw) ?? bgRaw,
          );
          if (parsed != null) {
            style = style.copyWith(backgroundColor: parsed);
          }
        }

        final size = attrs['size'];
        if (size != null) {
          final fs = _fontSizeFor(size, base.fontSize ?? 14);
          if (fs != null) style = style.copyWith(fontSize: fs);
        }
      }

      spans.add(TextSpan(text: insert, style: style));
    }
    return spans;
  }

  static double? _fontSizeFor(Object size, double base) {
    if (size is num) return size.toDouble();
    if (size is! String) return null;
    final s = size.trim().toLowerCase();
    switch (s) {
      case 'small':
        return base * 0.75;
      case 'large':
        return base * 1.5;
      case 'huge':
        return base * 2.5;
    }
    if (s.endsWith('px')) {
      return double.tryParse(s.substring(0, s.length - 2));
    }
    return double.tryParse(s);
  }

  /// Parses `#RGB`, `#RRGGBB`, `#AARRGGBB`, or `rgb(...)`.
  static Color? _parseCssColor(String raw) {
    final v = raw.trim();
    if (v.startsWith('#') && v.length >= 4) {
      var hex = v.substring(1);
      if (hex.length == 3) {
        hex = hex.split('').map((c) => '$c$c').join();
      }
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length == 8) {
        final n = int.tryParse(hex, radix: 16);
        if (n != null) return Color(n);
      }
    }
    final rgb = RegExp(
      r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',
    ).firstMatch(v);
    if (rgb != null) {
      return Color.fromARGB(
        255,
        int.parse(rgb.group(1)!),
        int.parse(rgb.group(2)!),
        int.parse(rgb.group(3)!),
      );
    }
    return null;
  }
}
