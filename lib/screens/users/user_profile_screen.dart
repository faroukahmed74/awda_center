import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/general_error_helper.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_service.dart';
import '../../services/firestore_service.dart';
import 'edit_user_privileges_dialog.dart';

/// Admin view of a user's profile: personal data, Edit (roles/permissions), Delete, and link to patient detail if patient.
class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirestoreService _firestore = FirestoreService();
  UserModel? _user;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final user = await _firestore.getUser(widget.userId);
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
        _errorMessage = user == null ? 'User not found' : null;
      });
    } catch (e, st) {
      debugPrint('UserProfileScreen _load error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = AppLocalizations.of(context).generalErrorMessage(generalErrorToMessageKey(e));
      });
    }
  }

  Future<void> _deleteUser() async {
    final u = _user;
    final auth = context.read<AuthProvider>();
    if (u == null || auth.currentUser?.id == u.id) return;
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteUser),
        content: Text(
          '${l10n.deleteConfirm} ${u.displayName} (${u.email})? '
          'Their account will be removed from authentication and Firestore; they will not be able to sign in again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await auth.deleteUserDocument(u.id);
    final current = auth.currentUser;
    if (current != null) {
      AuditService.log(
        action: 'user_deleted',
        entityType: 'user',
        entityId: u.id,
        userId: current.id,
        userEmail: current.email,
        details: {'targetEmail': u.email},
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final isRtl = l10n.isArabic;
    final isAdmin = auth.currentUser?.canAccessAdminDashboard ?? false;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.viewProfile),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/users'); }),
          actions: [
            if (isAdmin && _user != null && _user!.id != auth.currentUser?.id) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.editUser,
                onPressed: () async {
                  final ok = await showDialog<bool>(context: context, builder: (_) => EditUserPrivilegesDialog(user: _user!));
                  if (ok == true && mounted) _load();
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.deleteUser,
                onPressed: _deleteUser,
              ),
            ],
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null || _user == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 16),
                          Text(_errorMessage ?? 'User not found', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 16),
                          FilledButton.icon(icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: _load),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: ResponsivePadding.all(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.personalData, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Text(_user!.displayName, style: Theme.of(context).textTheme.titleLarge),
                                if (_user!.fullNameAr != null && _user!.fullNameAr!.isNotEmpty)
                                  Text('${l10n.fullNameAr}: ${_user!.fullNameAr}', style: Theme.of(context).textTheme.bodyMedium),
                                if (_user!.fullNameEn != null && _user!.fullNameEn!.isNotEmpty)
                                  Text('${l10n.fullNameEn}: ${_user!.fullNameEn}', style: Theme.of(context).textTheme.bodyMedium),
                                Text('${l10n.email}: ${_user!.email}', style: Theme.of(context).textTheme.bodyMedium),
                                if (_user!.phone != null && _user!.phone!.isNotEmpty)
                                  Text('${l10n.phone}: ${_user!.phone}', style: Theme.of(context).textTheme.bodyMedium),
                                Text('${l10n.role}: ${_user!.roles.map((r) => l10n.roleDisplay(r)).join(", ")}', style: Theme.of(context).textTheme.bodySmall),
                                Text(_user!.isActive ? l10n.active : l10n.inactive, style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ),
                        if (isAdmin && _user!.hasRole(UserRole.patient)) ...[
                          const SizedBox(height: 16),
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(l10n.patientDetail),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/patients/${_user!.id}'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}
