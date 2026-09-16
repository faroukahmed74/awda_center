import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import 'medical_rich_text_html.dart';

/// Quill-based medical notes editor with bold / underline / size / color toolbar.
/// Stores a small HTML subset via [htmlValue].
class MedicalRichTextField extends StatefulWidget {
  const MedicalRichTextField({
    super.key,
    required this.label,
    this.initialHtml,
    this.minHeight = 120,
  });

  final String label;
  final String? initialHtml;
  final double minHeight;

  @override
  State<MedicalRichTextField> createState() => MedicalRichTextFieldState();
}

class MedicalRichTextFieldState extends State<MedicalRichTextField> {
  late QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = _controllerFromStored(widget.initialHtml);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  QuillController _controllerFromStored(String? stored) {
    final raw = (stored ?? '').trim();
    Document doc;
    if (raw.isEmpty) {
      doc = Document();
    } else if (MedicalRichTextHtml.isLikelyHtml(raw)) {
      try {
        final delta = HtmlToDelta().convert(raw);
        doc = Document.fromDelta(delta);
      } catch (_) {
        doc = Document()..insert(0, MedicalRichTextHtml.htmlToPlainText(raw));
      }
    } else {
      doc = Document()..insert(0, raw);
    }
    return QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  /// HTML for Firestore, or `null` when empty.
  String? get htmlValue {
    final plain = _controller.document.toPlainText().trim();
    if (plain.isEmpty) return null;
    try {
      final ops = _controller.document.toDelta().toJson();
      final list = <Map<String, dynamic>>[
        for (final op in ops) Map<String, dynamic>.from(op as Map),
      ];
      final html = QuillDeltaToHtmlConverter(
        list,
        ConverterOptions.forEmail(),
      ).convert().trim();
      if (html.isEmpty || MedicalRichTextHtml.isEmpty(html)) return null;
      return html;
    } catch (_) {
      return plain.isEmpty ? null : plain;
    }
  }

  static const _toolbarConfig = QuillSimpleToolbarConfig(
    multiRowsDisplay: false,
    showDividers: false,
    showFontFamily: false,
    showFontSize: true,
    showBoldButton: true,
    showItalicButton: false,
    showSmallButton: false,
    showUnderLineButton: true,
    showLineHeightButton: false,
    showStrikeThrough: false,
    showInlineCode: false,
    showColorButton: true,
    showBackgroundColorButton: false,
    showClearFormat: true,
    showAlignmentButtons: false,
    showHeaderStyle: false,
    showListNumbers: false,
    showListBullets: false,
    showListCheck: false,
    showCodeBlock: false,
    showQuote: false,
    showIndent: false,
    showLink: false,
    showUndo: true,
    showRedo: true,
    showDirection: false,
    showSearchButton: false,
    showSubscript: false,
    showSuperscript: false,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuillSimpleToolbar(
            controller: _controller,
            config: _toolbarConfig,
          ),
          Divider(height: 1, color: theme.dividerColor),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: widget.minHeight,
              maxHeight: widget.minHeight * 2.2,
            ),
            child: QuillEditor.basic(
              controller: _controller,
              focusNode: _focusNode,
              scrollController: _scrollController,
              config: QuillEditorConfig(
                padding: const EdgeInsets.symmetric(vertical: 8),
                placeholder: widget.label,
                minHeight: widget.minHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
