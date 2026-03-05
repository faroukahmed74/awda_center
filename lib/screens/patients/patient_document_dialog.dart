import 'package:flutter/material.dart';
import '../../core/general_error_helper.dart';
import '../../l10n/app_localizations.dart';
import '../../models/patient_profile_model.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Add or edit a patient profile item: note (text), image (URL), or PDF (URL).
/// Each item is stored with createdAt/updatedAt for ordering (newest first).
class PatientDocumentDialog extends StatefulWidget {
  final String patientId;
  final String? currentUserId;
  final PatientDocumentModel? existing;
  final bool canEdit;

  const PatientDocumentDialog({
    super.key,
    required this.patientId,
    this.currentUserId,
    this.existing,
    this.canEdit = true,
  });

  @override
  State<PatientDocumentDialog> createState() => _PatientDocumentDialogState();
}

class _PatientDocumentDialogState extends State<PatientDocumentDialog> {
  final FirestoreService _firestore = FirestoreService();
  final StorageService _storage = StorageService();
  final _formKey = GlobalKey<FormState>();
  late DocumentType _type;
  late TextEditingController _textContent;
  late TextEditingController _fileUrl;
  late TextEditingController _fileName;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.documentType ?? DocumentType.note;
    _textContent = TextEditingController(text: e?.textContent ?? '');
    _fileUrl = TextEditingController(text: e?.filePathOrUrl ?? '');
    _fileName = TextEditingController(text: e?.fileName ?? '');
  }

  @override
  void dispose() {
    _textContent.dispose();
    _fileUrl.dispose();
    _fileName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!widget.canEdit) return;
    if (!_formKey.currentState!.validate()) return;
    final url = _fileUrl.text.trim();
    if (_type != DocumentType.note && url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).uploadOrPasteUrl)),
        );
      }
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final filePathOrUrl = _type != DocumentType.note ? url : '';
    final fileName = _type != DocumentType.note ? _fileName.text.trim() : '';
    try {
      if (widget.existing != null) {
        final data = <String, dynamic>{
          'documentType': _type.value,
          'textContent': _type == DocumentType.note ? _textContent.text.trim() : null,
          'filePathOrUrl': filePathOrUrl,
          'fileName': fileName,
        };
        await _firestore.updatePatientDocument(widget.existing!.id, data);
      } else {
        await _firestore.addPatientDocument(PatientDocumentModel(
          id: '',
          patientId: widget.patientId,
          documentType: _type,
          filePathOrUrl: filePathOrUrl,
          fileName: fileName.isNotEmpty ? fileName : _type.value,
          textContent: _type == DocumentType.note ? _textContent.text.trim() : null,
          uploadedByUserId: widget.currentUserId,
          createdAt: now,
          updatedAt: now,
        ));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).generalErrorMessage(generalErrorToMessageKey(e)))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? l10n.editDocument : l10n.addNote),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isEdit)
                DropdownButtonFormField<DocumentType>(
                  value: _type,
                  decoration: InputDecoration(labelText: l10n.type),
                  items: [
                    DropdownMenuItem(value: DocumentType.note, child: Text(l10n.notes)),
                    DropdownMenuItem(value: DocumentType.image, child: Text(l10n.addImage)),
                    DropdownMenuItem(value: DocumentType.pdf, child: Text(l10n.addPdf)),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? DocumentType.note),
                ),
              if (!isEdit) const SizedBox(height: 12),
              if (_type == DocumentType.note) ...[
                TextFormField(
                  controller: _textContent,
                  decoration: InputDecoration(labelText: l10n.notes),
                  maxLines: 5,
                  validator: (v) => (_type == DocumentType.note && (v == null || v.trim().isEmpty)) ? l10n.required : null,
                ),
              ] else ...[
                OutlinedButton.icon(
                  icon: _uploading
                      ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.upload_file),
                  label: Text(_uploading ? l10n.uploading : l10n.uploadFileImageOrPdf),
                  onPressed: _uploading
                      ? null
                      : () async {
                          setState(() => _uploading = true);
                          try {
                            final r = await _storage.pickAndUploadForPatient(widget.patientId);
                            if (r != null && mounted) {
                              setState(() {
                                _fileUrl.text = r.url;
                                _fileName.text = r.fileName;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('File uploaded. Tap Save to store the document.')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppLocalizations.of(context).generalErrorMessage(generalErrorToMessageKey(e))),
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          }
                          if (mounted) setState(() => _uploading = false);
                        },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fileUrl,
                  decoration: InputDecoration(labelText: l10n.orPasteUrlImageOrPdf),
                  validator: (v) => (_type != DocumentType.note && (v == null || v.trim().isEmpty)) ? l10n.uploadOrPasteUrl : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fileName,
                  decoration: InputDecoration(labelText: l10n.titleOrFileName),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.save),
        ),
      ],
    );
  }
}

/// Format date and time for display (newest first in list).
String formatDocumentDateTime(DateTime? createdAt, DateTime? updatedAt, AppLocalizations l10n) {
  if (createdAt == null) return '';
  final created = '${l10n.addedAt}: ${DateFormat.yMMMd().add_Hm().format(createdAt)}';
  if (updatedAt != null && updatedAt.isAfter(createdAt)) {
    return '$created • ${l10n.updatedAt}: ${DateFormat.yMMMd().add_Hm().format(updatedAt)}';
  }
  return created;
}
