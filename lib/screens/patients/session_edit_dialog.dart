import 'package:flutter/material.dart';
import '../../core/date_format.dart';
import '../../l10n/app_localizations.dart';
import '../../models/session_model.dart';

/// Admin dialog to edit a session (sessions collection) fields.
class SessionEditDialog extends StatefulWidget {
  final SessionModel session;

  const SessionEditDialog({super.key, required this.session});

  @override
  State<SessionEditDialog> createState() => _SessionEditDialogState();
}

class _SessionEditDialogState extends State<SessionEditDialog> {
  late DateTime _sessionDate;
  late TextEditingController _startTime;
  late TextEditingController _endTime;
  late TextEditingController _service;
  late TextEditingController _notes;
  late TextEditingController _progressNotes;
  late TextEditingController _vas;
  late TextEditingController _rom;
  late TextEditingController _functionNote;
  late TextEditingController _feesAmount;
  late TextEditingController _discountPercent;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _sessionDate = s.sessionDate;
    _startTime = TextEditingController(text: s.startTime);
    _endTime = TextEditingController(text: s.endTime);
    _service = TextEditingController(text: s.service ?? '');
    _notes = TextEditingController(text: s.notes ?? '');
    _progressNotes = TextEditingController(text: s.progressNotes ?? '');
    _vas = TextEditingController(text: s.vas ?? '');
    _rom = TextEditingController(text: s.rom ?? '');
    _functionNote = TextEditingController(text: s.functionNote ?? '');
    _feesAmount = TextEditingController(text: s.feesAmount?.toString() ?? '');
    _discountPercent = TextEditingController(text: s.discountPercent?.toString() ?? '');
  }

  @override
  void dispose() {
    _startTime.dispose();
    _endTime.dispose();
    _service.dispose();
    _notes.dispose();
    _progressNotes.dispose();
    _vas.dispose();
    _rom.dispose();
    _functionNote.dispose();
    _feesAmount.dispose();
    _discountPercent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editSession),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(AppDateFormat.mediumDate().format(_sessionDate)),
              subtitle: Text(l10n.date),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _sessionDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _sessionDate = d);
              },
            ),
            TextField(controller: _startTime, decoration: InputDecoration(labelText: '${l10n.time} (start)')),
            TextField(controller: _endTime, decoration: InputDecoration(labelText: '${l10n.time} (end)')),
            TextField(controller: _service, decoration: InputDecoration(labelText: l10n.service)),
            TextField(controller: _notes, decoration: InputDecoration(labelText: l10n.notes), maxLines: 2),
            TextField(controller: _progressNotes, decoration: const InputDecoration(labelText: 'Progress notes'), maxLines: 2),
            TextField(controller: _vas, decoration: const InputDecoration(labelText: 'VAS')),
            TextField(controller: _rom, decoration: const InputDecoration(labelText: 'ROM')),
            TextField(controller: _functionNote, decoration: const InputDecoration(labelText: 'Function note'), maxLines: 2),
            TextField(controller: _feesAmount, decoration: InputDecoration(labelText: '${l10n.amount} (fees)'), keyboardType: TextInputType.number),
            TextField(controller: _discountPercent, decoration: InputDecoration(labelText: l10n.discountPercent), keyboardType: TextInputType.number),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_buildData()),
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Map<String, dynamic> _buildData() {
    return {
      'sessionDate': _sessionDate,
      'startTime': _startTime.text.trim(),
      'endTime': _endTime.text.trim(),
      'service': _service.text.trim().isEmpty ? null : _service.text.trim(),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'progressNotes': _progressNotes.text.trim().isEmpty ? null : _progressNotes.text.trim(),
      'vas': _vas.text.trim().isEmpty ? null : _vas.text.trim(),
      'rom': _rom.text.trim().isEmpty ? null : _rom.text.trim(),
      'functionNote': _functionNote.text.trim().isEmpty ? null : _functionNote.text.trim(),
      'feesAmount': double.tryParse(_feesAmount.text.trim()),
      'discountPercent': double.tryParse(_discountPercent.text.trim()),
    };
  }
}
