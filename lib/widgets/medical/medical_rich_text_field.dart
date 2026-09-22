import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';

import 'medical_color_picker.dart';
import 'medical_format_clipboard.dart';
import 'medical_rich_text_html.dart';

/// Quill-based medical notes editor with bold / underline / size / color toolbar.
/// Persists Quill Delta JSON (lossless colors) in Firestore string fields.
class MedicalRichTextField extends StatefulWidget {
  const MedicalRichTextField({
    super.key,
    required this.label,
    this.initialHtml,
    this.minHeight = 120,
    this.labelColor,
    this.onLabelColorChanged,
  });

  final String label;
  /// Stored value: Delta JSON, HTML, or plain text.
  final String? initialHtml;
  final double minHeight;
  final Color? labelColor;
  final ValueChanged<Color?>? onLabelColorChanged;

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
    } else if (MedicalRichTextHtml.isDeltaJson(raw)) {
      try {
        final ops = MedicalRichTextHtml.deltaOpsFromStored(raw);
        doc = Document.fromDelta(Delta.fromJson(ops));
      } catch (_) {
        doc = Document()..insert(0, MedicalRichTextHtml.htmlToPlainText(raw));
      }
    } else if (MedicalRichTextHtml.isLikelyHtml(raw)) {
      try {
        final prepared = MedicalRichTextHtml.prepareHtmlForImport(raw);
        final delta = HtmlToDelta().convert(prepared);
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

  /// Value for Firestore, or `null` when empty.
  String? get htmlValue {
    final plain = _controller.document.toPlainText().trim();
    if (plain.isEmpty) return null;
    try {
      final ops = _controller.document.toDelta().toJson();
      return MedicalRichTextHtml.encodeDeltaOps(ops);
    } catch (_) {
      return plain.isEmpty ? null : plain;
    }
  }

  Future<void> _pickLabelColor() async {
    final onChanged = widget.onLabelColorChanged;
    if (onChanged == null) return;
    final picked = await showMedicalColorPicker(
      context,
      current: widget.labelColor,
    );
    if (!mounted || picked == null) return;
    if (isClearColor(picked)) {
      onChanged(null);
    } else {
      onChanged(picked);
    }
  }

  QuillSimpleToolbarConfig get _toolbarConfig => QuillSimpleToolbarConfig(
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
        customButtons: [
          QuillToolbarCustomButtonOptions(
            tooltip:
                'Copy format / paste format (long-press to clear copied style)',
            childBuilder: (options, extra) {
              return ListenableBuilder(
                listenable: MedicalFormatClipboard.instance,
                builder: (context, _) {
                  final has = MedicalFormatClipboard.instance.hasFormat;
                  final theme = Theme.of(context);
                  return IconButton(
                    tooltip: has
                        ? 'Paste format (long-press to clear)'
                        : 'Copy format from selection',
                    icon: Icon(
                      Icons.format_paint,
                      color: has ? theme.colorScheme.primary : null,
                    ),
                    isSelected: has,
                    onPressed: () {
                      MedicalFormatClipboard.instance
                          .toggleCopyOrPaste(extra.controller);
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      if (messenger == null) return;
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            MedicalFormatClipboard.instance.hasFormat &&
                                    !has
                                ? 'Style copied — select text in any field and tap paint to paste'
                                : 'Style applied',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    onLongPress: () {
                      MedicalFormatClipboard.instance.clear();
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(
                          content: Text('Copied style cleared'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: widget.labelColor,
    );

    return InputDecorator(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.label, style: labelStyle)),
              if (widget.onLabelColorChanged != null)
                IconButton(
                  tooltip: 'Label color',
                  icon: Icon(
                    Icons.palette_outlined,
                    color: widget.labelColor ?? theme.iconTheme.color,
                  ),
                  onPressed: _pickLabelColor,
                ),
            ],
          ),
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
