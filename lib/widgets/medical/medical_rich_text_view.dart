import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import 'medical_rich_text_html.dart';

/// Renders medical-detail HTML (or plain text for legacy values).
class MedicalRichTextView extends StatelessWidget {
  const MedicalRichTextView({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.bodyStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? bodyStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final resolvedLabel = labelStyle ??
        theme.bodySmall?.copyWith(fontWeight: FontWeight.w600);
    final resolvedBody = bodyStyle ?? theme.bodySmall;

    if (!MedicalRichTextHtml.isLikelyHtml(value)) {
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
          const SizedBox(height: 2),
          Html(
            data: value,
            style: {
              'body': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontSize: FontSize(resolvedBody?.fontSize ?? 13),
                color: resolvedBody?.color,
                lineHeight: LineHeight.number(1.35),
              ),
              'p': Style(
                margin: Margins.only(bottom: 4),
              ),
              'strong': Style(fontWeight: FontWeight.bold),
              'b': Style(fontWeight: FontWeight.bold),
              'u': Style(textDecoration: TextDecoration.underline),
              'span': Style(),
            },
          ),
        ],
      ),
    );
  }
}
