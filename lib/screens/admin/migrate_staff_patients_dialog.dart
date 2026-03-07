import 'package:flutter/material.dart';
import '../../core/general_error_helper.dart';
import '../../l10n/app_localizations.dart';
import '../../services/firestore_service.dart';

class MigrateStaffPatientsDialog extends StatefulWidget {
  const MigrateStaffPatientsDialog({super.key});

  @override
  State<MigrateStaffPatientsDialog> createState() => _MigrateStaffPatientsDialogState();
}

class _MigrateStaffPatientsDialogState extends State<MigrateStaffPatientsDialog> {
  final FirestoreService _firestore = FirestoreService();
  List<String> _ids = [];
  bool _loadingIds = true;
  bool _migrating = false;
  int _current = 0;
  String? _errorMessage;
  List<String> _errors = [];

  @override
  void initState() {
    super.initState();
    _loadIds();
  }

  Future<void> _loadIds() async {
    try {
      final ids = await _firestore.getStaffCreatedPatientIds();
      if (mounted) {
        setState(() {
          _ids = ids;
          _loadingIds = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingIds = false;
          _errorMessage = AppLocalizations.of(context).generalErrorMessage(generalErrorToMessageKey(e));
        });
      }
    }
  }

  Future<void> _runMigration() async {
    if (_ids.isEmpty) return;
    setState(() {
      _migrating = true;
      _errorMessage = null;
      _errors = [];
      _current = 0;
    });
    for (var i = 0; i < _ids.length; i++) {
      if (!mounted) return;
      setState(() => _current = i + 1);
      try {
        await _firestore.migrateStaffCreatedPatient(_ids[i]);
      } catch (e) {
        if (mounted) {
          setState(() => _errors.add('${_ids[i]}: ${generalErrorToMessageKey(e)}'));
        }
      }
    }
    if (mounted) {
      setState(() => _migrating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: AlertDialog(
        title: Text(l10n.migrateStaffCreatedPatientsDialogTitle),
        content: _loadingIds
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            : _errorMessage != null
                ? Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error))
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_ids.isEmpty)
                          Text(l10n.migrateStaffCreatedPatientsNone)
                        else ...[
                          Text(l10n.migrateStaffCreatedPatientsDialogMessage(_ids.length)),
                          if (_migrating) ...[
                            const SizedBox(height: 16),
                            Text(l10n.migrateStaffCreatedPatientsProgress(_current, _ids.length)),
                            const SizedBox(height: 8),
                            const LinearProgressIndicator(),
                          ],
                          if (!_migrating && _current == _ids.length && _ids.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errors.isEmpty ? l10n.migrateStaffCreatedPatientsDone : l10n.migrateStaffCreatedPatientsError,
                              style: _errors.isEmpty ? null : TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                            if (_errors.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(_errors.join('\n'), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error)),
                              ),
                          ],
                        ],
                      ],
                    ),
                  ),
        actions: [
          if (!_loadingIds && !_migrating)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
          if (!_loadingIds && _ids.isNotEmpty && !_migrating && _current == 0)
            FilledButton(
              onPressed: _runMigration,
              child: Text(l10n.confirm),
            ),
          if (!_loadingIds && (_ids.isEmpty || _current == _ids.length) && !_migrating)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('OK'),
            ),
        ],
      ),
    );
  }
}
