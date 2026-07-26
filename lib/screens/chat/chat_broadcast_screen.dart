import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_service.dart';
import '../../services/chat_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/main_app_bar_actions.dart';

class ChatBroadcastScreen extends StatefulWidget {
  const ChatBroadcastScreen({super.key});

  @override
  State<ChatBroadcastScreen> createState() => _ChatBroadcastScreenState();
}

class _ChatBroadcastScreenState extends State<ChatBroadcastScreen> {
  final ChatService _chat = ChatService();
  final FirestoreService _fs = FirestoreService();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  List<UserModel> _users = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _sending = false;
  String _roleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await _fs.getUsers();
    if (!mounted) return;
    setState(() {
      _users = list.where((u) => u.isActive).toList();
      _loading = false;
    });
  }

  List<UserModel> get _filtered {
    final me = context.read<AuthProvider>().currentUser?.id;
    return _users.where((u) {
      if (u.id == me) return false;
      if (_roleFilter == 'all') return true;
      return u.roles.contains(_roleFilter);
    }).toList();
  }

  Future<void> _send() async {
    final user = context.read<AuthProvider>().currentUser;
    final l10n = AppLocalizations.of(context);
    if (user == null || !user.canBroadcastChat) return;
    final text = _body.text.trim();
    if (text.isEmpty || _selected.isEmpty) return;
    setState(() => _sending = true);
    try {
      final id = await _chat.createBroadcast(
        senderId: user.id,
        recipientIds: _selected.toList(),
        title: _title.text.trim().isEmpty ? l10n.chatBroadcast : _title.text.trim(),
        text: text,
      );
      AuditService.log(
        action: 'chat_broadcast',
        entityType: 'conversation',
        entityId: id,
        userId: user.id,
        userEmail: user.email,
        details: {'recipients': _selected.length},
      );
      if (!mounted) return;
      context.pushReplacement('/chat/$id');
    } catch (e, st) {
      debugPrint('Broadcast send failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatSendFailed)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null || !user.canAccessChat || !user.canBroadcastChat) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.chatBroadcast)),
        body: Center(child: Text(l10n.generalErrorMessage('errorPermissionDenied'))),
      );
    }

    final list = _filtered;

    return Directionality(
      textDirection: l10n.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.chatBroadcast),
          actions: MainAppBarActions.notificationsLanguageTheme(context),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _title,
                    decoration: InputDecoration(
                      labelText: l10n.chatBroadcastTitle,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _body,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: l10n.typeMessage,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final r in ['all', 'patient', 'doctor', 'secretary', 'trainee', 'admin'])
                        FilterChip(
                          label: Text(r == 'all' ? l10n.allChats : r),
                          selected: _roleFilter == r,
                          onSelected: (_) {
                            setState(() {
                              _roleFilter = r;
                              if (r != 'all') {
                                _selected
                                  ..clear()
                                  ..addAll(list.map((u) => u.id));
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() {
                          _selected
                            ..clear()
                            ..addAll(list.map((u) => u.id));
                        }),
                        child: Text(l10n.selectAll),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _selected.clear()),
                        child: Text(l10n.clearSelection),
                      ),
                      Text('${_selected.length}'),
                    ],
                  ),
                  ...list.map((u) => CheckboxListTile(
                        dense: true,
                        value: _selected.contains(u.id),
                        title: Text(u.displayName),
                        subtitle: Text(u.roleValue),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(u.id);
                            } else {
                              _selected.remove(u.id);
                            }
                          });
                        },
                      )),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _sending || _selected.isEmpty || _body.text.trim().isEmpty
                        ? null
                        : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.send),
                  ),
                ],
              ),
      ),
    );
  }
}
