import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../widgets/notifications_button.dart';
import '../admin/invite_user_dialog.dart';
import 'edit_user_privileges_dialog.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final FirestoreService _firestore = FirestoreService();
  String? _roleFilter;
  String _searchQuery = '';
  List<UserModel> _allUsers = [];
  bool _loading = true;
  String? _errorMessage;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  List<UserModel> get _users {
    var out = _allUsers;
    if (_roleFilter != null && _roleFilter!.isNotEmpty) {
      out = out.where((u) => u.roles.contains(_roleFilter)).toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((u) {
        final name = u.displayName.toLowerCase();
        final email = u.email.toLowerCase();
        final phone = (u.phone ?? '').toLowerCase();
        return name.contains(q) || email.contains(q) || phone.contains(q);
      }).toList();
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _listen() {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    _subscription?.cancel();
    _subscription = _firestore.usersStream().listen(
      (snapshot) {
        final list = snapshot.docs.map((d) => UserModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
        if (mounted) setState(() {
          _allUsers = list;
          _loading = false;
          _errorMessage = null;
        });
      },
      onError: (e, st) {
        if (mounted) setState(() {
          _loading = false;
          _errorMessage = AppLocalizations.of(context).generalErrorMessage(generalErrorToMessageKey(e));
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.users),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: [
            const NotificationsButton(),
            if (auth.currentUser?.canAccessAdminDashboard ?? false)
              IconButton(
                icon: const Icon(Icons.person_add),
                tooltip: l10n.inviteUser,
                onPressed: () async {
                  final ok = await showDialog<bool>(context: context, builder: (_) => const InviteUserDialog());
                  if (ok == true && mounted) { _subscription?.cancel(); _listen(); }
                },
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButton<String?>(
                value: _roleFilter,
                hint: Text(l10n.filterByRole),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.allRoles)),
                  DropdownMenuItem(value: 'admin', child: Text(l10n.admin)),
                  DropdownMenuItem(value: 'doctor', child: Text(l10n.doctor)),
                  DropdownMenuItem(value: 'patient', child: Text(l10n.patient)),
                  DropdownMenuItem(value: 'secretary', child: Text(l10n.secretary)),
                  DropdownMenuItem(value: 'trainee', child: Text(l10n.trainee)),
                ],
                onChanged: (v) => setState(() => _roleFilter = v),
              ),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: l10n.searchUsersHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _searchQuery = ''),
                        ),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton.icon(icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: () { _subscription?.cancel(); _listen(); }),
                        ],
                      ),
                    ),
                  )
                                : _users.isEmpty
                                    ? Center(child: Text(l10n.noData))
                                    : ListView.builder(
                    padding: responsiveListPadding(context),
                    itemCount: _users.length,
                    itemBuilder: (context, i) {
                      final u = _users[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(child: Text(u.displayName)),
                              if (!u.isActive)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Chip(
                                    label: Text(l10n.inactive, style: const TextStyle(fontSize: 12)),
                                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            [
                              u.email,
                              u.roles.map((r) => l10n.roleDisplay(r)).join(', '),
                            ].where((e) => e.isNotEmpty).join(' • '),
                          ),
                          trailing: auth.currentUser?.canAccessAdminDashboard == true
                              ? PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  tooltip: l10n.edit,
                                  onSelected: (value) async {
                                    switch (value) {
                                      case 'view_profile':
                                        context.push('/users/${u.id}');
                                        break;
                                      case 'edit':
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => EditUserPrivilegesDialog(user: u),
                                        );
                                        if (ok == true && mounted) { _subscription?.cancel(); _listen(); }
                                        break;
                                      case 'toggle_active':
                                        await auth.updateUserActive(u.id, !u.isActive);
                                        final current = auth.currentUser;
                                        if (current != null) {
                                          AuditService.log(
                                            action: u.isActive ? 'user_deactivated' : 'user_activated',
                                            entityType: 'user',
                                            entityId: u.id,
                                            userId: current.id,
                                            userEmail: current.email,
                                            details: {'targetEmail': u.email},
                                          );
                                        }
                                        if (mounted) { _subscription?.cancel(); _listen(); }
                                        break;
                                      case 'delete':
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(l10n.deleteUser),
                                            content: Text(
                                              '${l10n.deleteConfirm} ${u.displayName} (${u.email})? '
                                              'Their Firestore profile will be removed. They will not appear in the app until they sign in again.',
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
                                        if (confirm == true && mounted) {
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
                                          { _subscription?.cancel(); _listen(); }
                                        }
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(value: 'view_profile', child: Row(children: [const Icon(Icons.person_outline, size: 20), const SizedBox(width: 12), Text(l10n.viewProfile)])),
                                    PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit, size: 20), const SizedBox(width: 12), Text(l10n.editUser)])),
                                    PopupMenuItem(value: 'toggle_active', child: Row(children: [Icon(u.isActive ? Icons.block : Icons.check_circle, size: 20), const SizedBox(width: 12), Text(u.isActive ? l10n.inactive : l10n.active)])),
                                    PopupMenuItem(
                                      value: 'delete',
                                      enabled: auth.currentUser?.id != u.id,
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 20, color: auth.currentUser?.id == u.id ? null : Theme.of(context).colorScheme.error),
                                          const SizedBox(width: 12),
                                          Text(l10n.deleteUser, style: auth.currentUser?.id == u.id ? null : TextStyle(color: Theme.of(context).colorScheme.error)),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
