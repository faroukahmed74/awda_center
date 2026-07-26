import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/chat_service.dart';

/// App-bar chat icon with live unread badge.
class ChatMessagesButton extends StatefulWidget {
  const ChatMessagesButton({super.key});

  @override
  State<ChatMessagesButton> createState() => _ChatMessagesButtonState();
}

class _ChatMessagesButtonState extends State<ChatMessagesButton> {
  final ChatService _chat = ChatService();
  StreamSubscription? _sub;
  int _unread = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().currentUser?.id;
    _sub?.cancel();
    if (uid == null) return;
    _sub = _chat.myConversationsStream(uid).listen((list) {
      var total = 0;
      for (final c in list) {
        total += c.unreadFor(uid);
      }
      if (mounted) setState(() => _unread = total);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null || !user.canAccessChat) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.messages,
      onPressed: () => context.push('/chat'),
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 99 ? '99+' : '$_unread'),
        child: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }
}
