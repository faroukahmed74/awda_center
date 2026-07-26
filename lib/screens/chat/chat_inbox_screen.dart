import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/date_format.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_conversation_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/main_app_bar_actions.dart';
import 'chat_thread_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  static const _privacyKey = 'chat_privacy_banner_dismissed';
  final ChatService _chat = ChatService();
  final FirestoreService _fs = FirestoreService();
  Map<String, UserModel> _usersById = {};
  bool _showAll = false;
  bool _showPrivacy = false;
  String? _selectedConversationId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadPrivacy();
  }

  Future<void> _loadPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _showPrivacy = !(prefs.getBool(_privacyKey) ?? false));
  }

  Future<void> _dismissPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyKey, true);
    if (mounted) setState(() => _showPrivacy = false);
  }

  Future<void> _loadUsers() async {
    final list = await _fs.getUsers();
    if (!mounted) return;
    setState(() {
      _usersById = {for (final u in list) u.id: u};
    });
  }

  String _titleFor(ChatConversationModel c, String myUid, AppLocalizations l10n) {
    if ((c.type == ChatConversationType.broadcast ||
            c.type == ChatConversationType.group) &&
        (c.title?.isNotEmpty ?? false)) {
      return c.title!;
    }
    final otherId = c.otherParticipantId(myUid);
    final other = _usersById[otherId];
    return other?.displayName ?? (otherId.isEmpty ? l10n.messages : otherId);
  }

  double _inboxPaneWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (Breakpoint.isDesktop(context)) {
      return (w * 0.28).clamp(320.0, 420.0);
    }
    return (w * 0.38).clamp(260.0, 380.0);
  }

  void _openNewChatMenu() {
    final l10n = AppLocalizations.of(context);
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (user.canStartChat && user.canMessageAnyone)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(l10n.newChat),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/chat/new');
                },
              ),
            if (user.canCreateChatGroup)
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: Text(l10n.chatNewGroup),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/chat/group/new');
                },
              ),
            if (user.canBroadcastChat)
              ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: Text(l10n.chatBroadcast),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/chat/broadcast');
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openConversation(String id, {required bool split}) {
    if (split) {
      setState(() => _selectedConversationId = id);
    } else {
      context.push('/chat/$id');
    }
  }

  bool _canDeleteConversation(UserModel user, ChatConversationModel c) {
    if (!user.canDeleteChat) return false;
    if (user.canDeleteAnyChat || user.canViewAllChats) return true;
    return c.participantIds.contains(user.id);
  }

  Future<void> _deleteConversation(UserModel user, ChatConversationModel c) async {
    final l10n = AppLocalizations.of(context);
    if (!_canDeleteConversation(user, c)) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chatDeleteChat),
        content: Text(
          c.type == ChatConversationType.group
              ? l10n.chatDeleteGroupConfirm
              : l10n.chatDeleteChatConfirm,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _chat.deleteConversation(c.id);
      if (_selectedConversationId == c.id && mounted) {
        setState(() => _selectedConversationId = null);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saved)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.generalErrorMessage('errorSaveFailed'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null || !user.canAccessChat) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.messages)),
        body: Center(child: Text(l10n.generalErrorMessage('errorPermissionDenied'))),
      );
    }

    final split = Breakpoint.isTabletOrWider(context);
    final stream = _showAll && user.canViewAllChats
        ? _chat.allConversationsStream()
        : _chat.myConversationsStream(user.id);

    final inboxList = StreamBuilder<List<ChatConversationModel>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: responsiveListPadding(context),
              child: Text(
                '${l10n.generalErrorMessage('errorLoadFailed')}\n\n${snap.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return Center(child: Text(l10n.chatNoConversations));
        }
        return ListView.separated(
          padding: responsiveListPadding(context),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final c = list[i];
            final unread = c.unreadFor(user.id);
            final when = c.lastMessageAt != null
                ? AppDateFormat.shortDateTime.format(c.lastMessageAt!)
                : '';
            final selected = split && _selectedConversationId == c.id;
            return ListTile(
              selected: selected,
              leading: CircleAvatar(
                child: Icon(
                  c.type == ChatConversationType.group
                      ? Icons.group
                      : c.type == ChatConversationType.broadcast
                          ? Icons.campaign
                          : Icons.person,
                  size: 20,
                ),
              ),
              title: Text(
                _titleFor(c, user.id, l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                c.type == ChatConversationType.group
                    ? '${c.participantIds.length} · ${c.lastMessageText ?? ''}'
                    : (c.lastMessageText ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (when.isNotEmpty)
                        Text(when, style: Theme.of(context).textTheme.bodySmall),
                      if (unread > 0) ...[
                        const SizedBox(height: 4),
                        Badge(label: Text('$unread')),
                      ],
                    ],
                  ),
                  if (_canDeleteConversation(user, c))
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'delete') _deleteConversation(user, c);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.chatDeleteChat),
                        ),
                      ],
                    ),
                ],
              ),
              onTap: () => _openConversation(c.id, split: split),
              onLongPress: _canDeleteConversation(user, c)
                  ? () => _deleteConversation(user, c)
                  : null,
            );
          },
        );
      },
    );

    return Directionality(
      textDirection: l10n.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.messages),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),
          actions: [
            if ((user.canStartChat && user.canMessageAnyone) ||
                user.canCreateChatGroup ||
                user.canBroadcastChat)
              IconButton(
                icon: const Icon(Icons.add_comment_outlined),
                tooltip: l10n.newChat,
                onPressed: _openNewChatMenu,
              ),
            if (user.canAccessChatSettings)
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: l10n.chatSettings,
                onPressed: () => context.push('/chat/settings'),
              ),
            ...MainAppBarActions.notificationsLanguageTheme(context),
          ],
        ),
        // Scaffold FAB only on phone — in split view it covered the thread Send button.
        floatingActionButton: !split &&
                ((user.canStartChat && user.canMessageAnyone) ||
                    user.canCreateChatGroup ||
                    user.canBroadcastChat)
            ? FloatingActionButton(
                tooltip: l10n.newChat,
                onPressed: _openNewChatMenu,
                child: const Icon(Icons.chat),
              )
            : null,
        body: Column(
          children: [
            if (_showPrivacy)
              MaterialBanner(
                content: Text(l10n.chatPrivacyNotice),
                actions: [
                  TextButton(
                    onPressed: _dismissPrivacy,
                    child: Text(l10n.ok),
                  ),
                ],
              ),
            if (user.canViewAllChats)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l10n.myChats)),
                    ButtonSegment(value: true, label: Text(l10n.allChats)),
                  ],
                  selected: {_showAll},
                  onSelectionChanged: (s) => setState(() => _showAll = s.first),
                ),
              ),
            Expanded(
              child: split
                  ? Row(
                      children: [
                        SizedBox(
                          width: _inboxPaneWidth(context),
                          child: Stack(
                            children: [
                              Positioned.fill(child: inboxList),
                              if ((user.canStartChat && user.canMessageAnyone) ||
                                  user.canCreateChatGroup ||
                                  user.canBroadcastChat)
                                PositionedDirectional(
                                  end: 16,
                                  bottom: 16,
                                  child: FloatingActionButton(
                                    tooltip: l10n.newChat,
                                    onPressed: _openNewChatMenu,
                                    child: const Icon(Icons.chat),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: _selectedConversationId == null
                              ? Center(child: Text(l10n.chatNoConversations))
                              : ChatThreadScreen(
                                  key: ValueKey(_selectedConversationId),
                                  conversationId: _selectedConversationId!,
                                  embedded: true,
                                ),
                        ),
                      ],
                    )
                  : inboxList,
            ),
          ],
        ),
      ),
    );
  }
}
