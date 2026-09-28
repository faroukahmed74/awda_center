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
        // Wrap buttons onto multiple rows so overflow chevrons (often broken on
        // web/desktop in narrow dialogs) are not needed to reach bold/color/etc.
        multiRowsDisplay: true,
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
            tooltip: 'Copy format / paste format',
            // Use `dynamic` params: Quill resolves childBuilder as
            // `(dynamic, dynamic) => Widget`, and typed closures throw a
            // subtype error on AOT (iOS/Android) → grey ErrorWidget boxes.
            childBuilder: (dynamic options, dynamic extra) {
              final extras = extra as QuillToolbarCustomButtonExtraOptions;
              return ListenableBuilder(
                listenable: MedicalFormatClipboard.instance,
                builder: (context, _) {
                  final has = MedicalFormatClipboard.instance.hasFormat;
                  final theme = Theme.of(context);
                  return IconButton(
                    tooltip: has
                        ? 'Paste format (clears after paste)'
                        : 'Copy format from selection',
                    icon: Icon(
                      Icons.format_paint,
                      color: has ? theme.colorScheme.primary : null,
                    ),
                    isSelected: has,
                    onPressed: () {
                      final wasCopying = has;
                      MedicalFormatClipboard.instance
                          .toggleCopyOrPaste(extras.controller);
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      if (messenger == null) return;
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            wasCopying
                                ? 'Style applied'
                                : 'Style copied — select text and tap paint to paste',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          QuillToolbarCustomButtonOptions(
            tooltip: 'Cancel copied format',
            childBuilder: (dynamic options, dynamic extra) {
              return ListenableBuilder(
                listenable: MedicalFormatClipboard.instance,
                builder: (context, _) {
                  if (!MedicalFormatClipboard.instance.hasFormat) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    tooltip: 'Cancel copied format',
                    icon: const Icon(Icons.close),
                    onPressed: () {
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
    // Quill defaults can leave empty editors looking like a solid grey slab on
    // dark mobile themes; force theme text/placeholder colors.
    final baseStyles = DefaultStyles.getInstance(context);
    final paragraphStyle = (baseStyles.paragraph?.style ??
            theme.textTheme.bodyMedium ??
            const TextStyle())
        .copyWith(color: theme.colorScheme.onSurface);
    final customStyles = baseStyles.merge(
      DefaultStyles(
        paragraph: DefaultTextBlockStyle(
          paragraphStyle,
          baseStyles.paragraph?.horizontalSpacing ??
              HorizontalSpacing.zero,
          baseStyles.paragraph?.verticalSpacing ?? VerticalSpacing.zero,
          baseStyles.paragraph?.lineSpacing ?? VerticalSpacing.zero,
          null,
        ),
        placeHolder: DefaultTextBlockStyle(
          paragraphStyle.copyWith(
            color: theme.hintColor,
          ),
          baseStyles.placeHolder?.horizontalSpacing ??
              HorizontalSpacing.zero,
          baseStyles.placeHolder?.verticalSpacing ?? VerticalSpacing.zero,
          baseStyles.placeHolder?.lineSpacing ?? VerticalSpacing.zero,
          null,
        ),
      ),
    );

    return InputDecorator(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
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
          // Fixed height so Quill gets bounded constraints inside the parent
          // SingleChildScrollView (unbounded height → blank grey editor on
          // iOS/Android).
          SizedBox(
            height: widget.minHeight,
            child: QuillEditor.basic(
              controller: _controller,
              focusNode: _focusNode,
              scrollController: _scrollController,
              config: QuillEditorConfig(
                scrollable: true,
                expands: true,
                autoFocus: false,
                padding: const EdgeInsets.symmetric(vertical: 8),
                placeholder: widget.label,
                customStyles: customStyles,
                keyboardAppearance: theme.brightness,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
