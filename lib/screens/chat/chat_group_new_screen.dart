import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_service.dart';
import '../../services/chat_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/main_app_bar_actions.dart';

class ChatGroupNewScreen extends StatefulWidget {
  const ChatGroupNewScreen({super.key});

  @override
  State<ChatGroupNewScreen> createState() => _ChatGroupNewScreenState();
}

class _ChatGroupNewScreenState extends State<ChatGroupNewScreen> {
  final ChatService _chat = ChatService();
  final FirestoreService _fs = FirestoreService();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _search = TextEditingController();
  List<UserModel> _users = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _search.dispose();
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

  Future<void> _create() async {
    final me = context.read<AuthProvider>().currentUser;
    final l10n = AppLocalizations.of(context);
    if (me == null || !me.canCreateChatGroup) return;
    final title = _title.text.trim();
    if (title.isEmpty || _selected.isEmpty) return;
    setState(() => _creating = true);
    try {
      final id = await _chat.createGroup(
        creatorId: me.id,
        memberIds: _selected.toList(),
        title: title,
      );
      AuditService.log(
        action: 'chat_group_created',
        entityType: 'conversation',
        entityId: id,
        userId: me.id,
        userEmail: me.email,
        details: {'members': _selected.length, 'title': title},
      );
      if (!mounted) return;
      context.pushReplacement('/chat/$id');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatSendFailed)),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = context.watch<AuthProvider>().currentUser;
    if (me == null || !me.canAccessChat || !me.canCreateChatGroup) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.chatNewGroup)),
        body: Center(child: Text(l10n.generalErrorMessage('errorPermissionDenied'))),
      );
    }

    final q = _search.text.trim().toLowerCase();
    final filtered = _users.where((u) {
      if (u.id == me.id) return false;
      if (q.isEmpty) return true;
      return u.displayName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (u.phone ?? '').contains(q);
    }).toList();

    final maxW = responsiveMaxContentWidth(context);

    return Directionality(
      textDirection: l10n.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.chatNewGroup),
          actions: MainAppBarActions.notificationsLanguageTheme(context),
        ),
        body: _creating
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW.isFinite ? maxW : 720),
                  child: Column(
                    children: [
                      Padding(
                        padding: ResponsivePadding.all(context),
                        child: Column(
                          children: [
                            TextField(
                              controller: _title,
                              decoration: InputDecoration(
                                labelText: l10n.chatGroupTitle,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _search,
                              decoration: InputDecoration(
                                hintText: l10n.chatSearchUsers,
                                prefixIcon: const Icon(Icons.search),
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                l10n.chatGroupMembersSelected(_selected.length),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                padding: responsiveListPadding(context),
                                itemCount: filtered.length,
                                itemBuilder: (context, i) {
                                  final u = filtered[i];
                                  return CheckboxListTile(
                                    value: _selected.contains(u.id),
                                    secondary: CircleAvatar(
                                      child: Text(
                                        u.displayName.isNotEmpty
                                            ? u.displayName.characters.first
                                            : '?',
                                      ),
                                    ),
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
                                  );
                                },
                              ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: ResponsivePadding.all(context),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _title.text.trim().isEmpty ||
                                      _selected.isEmpty
                                  ? null
                                  : _create,
                              child: Text(l10n.chatCreateGroup),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
