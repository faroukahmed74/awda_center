import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_conversation_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_service.dart';
import '../../services/chat_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/main_app_bar_actions.dart';

/// Group info + CRUD: rename, add/remove members, delete group.
class ChatGroupInfoScreen extends StatefulWidget {
  final String conversationId;

  const ChatGroupInfoScreen({super.key, required this.conversationId});

  @override
  State<ChatGroupInfoScreen> createState() => _ChatGroupInfoScreenState();
}

class _ChatGroupInfoScreenState extends State<ChatGroupInfoScreen> {
  final ChatService _chat = ChatService();
  final FirestoreService _fs = FirestoreService();
  ChatConversationModel? _conv;
  Map<String, UserModel> _usersById = {};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _canManage(UserModel me) {
    if (_conv == null || _conv!.type != ChatConversationType.group) return false;
    if (me.canManageChatGroup || me.canDeleteAnyChat) return true;
    if (_conv!.createdBy == me.id) return true;
    return false;
  }

  Future<void> _load() async {
    final users = await _fs.getUsers();
    final conv = await _chat.getConversation(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _usersById = {for (final u in users) u.id: u};
      _conv = conv;
      _loading = false;
    });
  }

  Future<void> _rename(UserModel me) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: _conv?.title ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chatRenameGroup),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.chatGroupTitle,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.save)),
        ],
      ),
    );
    final title = controller.text.trim();
    controller.dispose();
    if (ok != true || title.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _chat.updateGroupTitle(
        conversationId: widget.conversationId,
        title: title,
        actorId: me.id,
      );
      AuditService.log(
        action: 'chat_group_renamed',
        entityType: 'conversation',
        entityId: widget.conversationId,
        userId: me.id,
        userEmail: me.email,
        details: {'title': title},
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.generalErrorMessage('errorSaveFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addMembers(UserModel me) async {
    final l10n = AppLocalizations.of(context);
    final existing = _conv?.participantIds.toSet() ?? {};
    final candidates = _usersById.values
        .where((u) => u.isActive && !existing.contains(u.id))
        .toList();
    final selected = <String>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.chatAddMembers),
          content: SizedBox(
            width: 400,
            height: 360,
            child: ListView.builder(
              itemCount: candidates.length,
              itemBuilder: (_, i) {
                final u = candidates[i];
                return CheckboxListTile(
                  dense: true,
                  value: selected.contains(u.id),
                  title: Text(u.displayName),
                  subtitle: Text(u.roleValue),
                  onChanged: (v) => setLocal(() {
                    if (v == true) {
                      selected.add(u.id);
                    } else {
                      selected.remove(u.id);
                    }
                  }),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (ok != true || selected.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _chat.addGroupMembers(
        conversationId: widget.conversationId,
        memberIds: selected.toList(),
        actorId: me.id,
      );
      AuditService.log(
        action: 'chat_group_members_added',
        entityType: 'conversation',
        entityId: widget.conversationId,
        userId: me.id,
        userEmail: me.email,
        details: {'added': selected.toList()},
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.generalErrorMessage('errorSaveFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeMember(UserModel me, String memberId) async {
    final l10n = AppLocalizations.of(context);
    if (memberId == me.id && !_canManage(me)) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chatRemoveMember),
        content: Text(l10n.chatRemoveMemberConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      await _chat.removeGroupMember(
        conversationId: widget.conversationId,
        memberId: memberId,
        actorId: me.id,
      );
      AuditService.log(
        action: 'chat_group_member_removed',
        entityType: 'conversation',
        entityId: widget.conversationId,
        userId: me.id,
        userEmail: me.email,
        details: {'removed': memberId},
      );
      if (memberId == me.id && mounted) {
        context.go('/chat');
        return;
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.generalErrorMessage('errorSaveFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteGroup(UserModel me) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chatDeleteGroup),
        content: Text(l10n.chatDeleteGroupConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      await _chat.deleteConversation(widget.conversationId);
      AuditService.log(
        action: 'chat_group_deleted',
        entityType: 'conversation',
        entityId: widget.conversationId,
        userId: me.id,
        userEmail: me.email,
      );
      if (mounted) context.go('/chat');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.generalErrorMessage('errorSaveFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = context.watch<AuthProvider>().currentUser;
    if (me == null || !me.canAccessChat) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.chatGroupInfo)),
        body: Center(child: Text(l10n.generalErrorMessage('errorPermissionDenied'))),
      );
    }

    final manage = _canManage(me);
    final members = _conv?.participantIds ?? const <String>[];

    return Directionality(
      textDirection: l10n.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.chatGroupInfo),
          actions: MainAppBarActions.notificationsLanguageTheme(context),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _conv == null || _conv!.type != ChatConversationType.group
                ? Center(child: Text(l10n.noData))
                : Stack(
                    children: [
                      ListView(
                        padding: responsiveListPadding(context),
                        children: [
                          ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.group)),
                            title: Text(_conv!.title ?? l10n.chatNewGroup),
                            subtitle: Text(
                              l10n.chatGroupMembersSelected(members.length),
                            ),
                            trailing: manage
                                ? IconButton(
                                    icon: const Icon(Icons.edit),
                                    tooltip: l10n.chatRenameGroup,
                                    onPressed: _busy ? null : () => _rename(me),
                                  )
                                : null,
                          ),
                          const Divider(),
                          if (manage)
                            ListTile(
                              leading: const Icon(Icons.person_add_alt),
                              title: Text(l10n.chatAddMembers),
                              onTap: _busy ? null : () => _addMembers(me),
                            ),
                          ...members.map((id) {
                            final u = _usersById[id];
                            final isCreator = _conv!.createdBy == id;
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  (u?.displayName.isNotEmpty ?? false)
                                      ? u!.displayName.characters.first
                                      : '?',
                                ),
                              ),
                              title: Text(u?.displayName ?? id),
                              subtitle: Text(
                                [
                                  u?.roleValue ?? '',
                                  if (isCreator) l10n.chatGroupCreator,
                                ].where((s) => s.isNotEmpty).join(' · '),
                              ),
                              trailing: manage && (id != me.id || me.canManageChatGroup)
                                  ? IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      tooltip: l10n.chatRemoveMember,
                                      onPressed: _busy
                                          ? null
                                          : () => _removeMember(me, id),
                                    )
                                  : (!manage && id == me.id)
                                      ? TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _removeMember(me, id),
                                          child: Text(l10n.chatLeaveGroup),
                                        )
                                      : null,
                            );
                          }),
                          if (manage) ...[
                            const Divider(),
                            ListTile(
                              leading: Icon(
                                Icons.delete_forever,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              title: Text(
                                l10n.chatDeleteGroup,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              onTap: _busy ? null : () => _deleteGroup(me),
                            ),
                          ],
                        ],
                      ),
                      if (_busy)
                        const ModalBarrier(dismissible: false, color: Colors.black26),
                      if (_busy)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
      ),
    );
  }
}
