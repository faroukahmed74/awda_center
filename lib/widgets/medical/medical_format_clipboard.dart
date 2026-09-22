import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Shared clipboard for Quill inline styles (format painter across medical fields).
class MedicalFormatClipboard extends ChangeNotifier {
  MedicalFormatClipboard._();
  static final MedicalFormatClipboard instance = MedicalFormatClipboard._();

  static const _keys = [
    'bold',
    'italic',
    'underline',
    'strike',
    'color',
    'background',
    'size',
  ];

  List<Attribute>? _attributes;

  bool get hasFormat => _attributes != null && _attributes!.isNotEmpty;

  void clear() {
    if (_attributes == null) return;
    _attributes = null;
    notifyListeners();
  }

  /// Copy inline styles from the current selection.
  void copyFrom(QuillController controller) {
    final style = controller.getSelectionStyle();
    final byKey = <String, Attribute>{};
    for (final key in _keys) {
      final attr = style.attributes[key];
      if (attr != null) {
        byKey[key] = attr;
      }
    }
    _attributes = byKey.values.toList();
    notifyListeners();
  }

  /// Apply copied styles to the current selection, then clear (one-shot paste).
  void applyTo(QuillController controller, {bool clearAfter = true}) {
    final attrs = _attributes;
    if (attrs == null || attrs.isEmpty) return;
    if (!controller.selection.isValid) return;
    for (final attr in attrs) {
      controller.formatSelection(attr);
    }
    if (clearAfter) clear();
  }

  /// Tap: copy if empty, otherwise paste once and release the brush.
  void toggleCopyOrPaste(QuillController controller) {
    if (hasFormat) {
      applyTo(controller, clearAfter: true);
    } else {
      copyFrom(controller);
    }
  }
}
