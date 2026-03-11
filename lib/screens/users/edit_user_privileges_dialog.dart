import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_permissions.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_service.dart';

/// Admin: edit user profile (name, phone), roles, permissions, and active status.
class EditUserPrivilegesDialog extends StatefulWidget {
  final UserModel user;

  const EditUserPrivilegesDialog({super.key, required this.user});

  @override
  State<EditUserPrivilegesDialog> createState() => _EditUserPrivilegesDialogState();
}

class _EditUserPrivilegesDialogState extends State<EditUserPrivilegesDialog> {
  late List<String> _roles;
  late List<String> _permissions;
  late TextEditingController _nameArController;
  late TextEditingController _nameEnController;
  late TextEditingController _phoneController;
  late bool _isActive;
  late bool _isStarred;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _roles = List.from(widget.user.roles);
    _permissions = List.from(widget.user.permissions);
    _nameArController = TextEditingController(text: widget.user.fullNameAr ?? '');
    _nameEnController = TextEditingController(text: widget.user.fullNameEn ?? '');
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _isActive = widget.user.isActive;
    _isStarred = widget.user.isStarred;
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _featureLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'admin_dashboard': return l10n.adminDashboard;
      case 'users': return l10n.users;
      case 'appointments': return l10n.appointments;
      case 'appointments_see_all': return l10n.appointmentsSeeAll;
      case 'appointments_view_all': return l10n.appointmentsViewAll;
      case 'patients': return l10n.patients;
      case 'income_expenses': return l10n.incomeAndExpenses;
      case 'finance_summary': return l10n.financeSummary;
      case 'reports': return l10n.reports;
      case 'requirements': return l10n.requirements;
      case 'admin_todos': return l10n.toDoList;
      default: return key;
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final uid = widget.user.id;
    await auth.updateUserProfile(
      uid,
      fullNameAr: _nameArController.text.trim().isEmpty ? null : _nameArController.text.trim(),
      fullNameEn: _nameEnController.text.trim().isEmpty ? null : _nameEnController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    );
    await auth.updateUserRoles(uid, _roles);
    await auth.updateUserPermissions(uid, _permissions);
    await auth.updateUserActive(uid, _isActive);
    if (widget.user.hasRole(UserRole.patient)) {
      await auth.updateUserStarred(uid, _isStarred);
    }
    final current = auth.currentUser;
    if (current != null) {
      AuditService.log(
        action: 'user_updated',
        entityType: 'user',
        entityId: uid,
        userId: current.id,
        userEmail: current.email,
        details: {
          'roles': _roles,
          'permissions': _permissions,
          'isActive': _isActive,
        },
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editUser),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.user.email, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(
              controller: _nameArController,
              decoration: InputDecoration(labelText: '${l10n.fullNameAr}'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameEnController,
              decoration: InputDecoration(labelText: '${l10n.fullNameEn}'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: l10n.phone),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: Text(l10n.active),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            if (widget.user.hasRole(UserRole.patient)) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                title: Row(
                  children: [
                    Icon(Icons.star, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(l10n.starredPatientVip),
                  ],
                ),
                value: _isStarred,
                onChanged: (v) => setState(() => _isStarred = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
            const SizedBox(height: 16),
            Text(l10n.role, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: UserRole.values.map((r) {
                final selected = _roles.contains(r.value);
                return FilterChip(
                  label: Text(r.value),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v == true) {
                        _roles.add(r.value);
                      } else {
                        _roles.remove(r.value);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Privileges (optional)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('If set, overrides role-based access.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            ...kAllFeatureKeys.map((key) => CheckboxListTile(
              title: Text(_featureLabel(key, l10n)),
              value: _permissions.contains(key),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _permissions.add(key);
                  } else {
                    _permissions.remove(key);
                  }
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            )),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.save),
        ),
      ],
    );
  }
}
