import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';

/// Opens (or creates) a direct chat with [otherUserId].
Future<void> openDirectChatWith(
  BuildContext context, {
  required String otherUserId,
}) async {
  final me = context.read<AuthProvider>().currentUser;
  final l10n = AppLocalizations.of(context);
  if (me == null || !me.canAccessChat || !me.canStartChat || !me.canMessageAnyone) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.generalErrorMessage('errorPermissionDenied'))),
    );
    return;
  }
  if (otherUserId.isEmpty || otherUserId == me.id) return;
  try {
    final id = await ChatService().openDirectChatId(
      myUid: me.id,
      otherUid: otherUserId,
    );
    if (context.mounted) context.push('/chat/$id');
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatSendFailed)),
      );
    }
  }
}

/// App-bar / list action to message another user.
Widget? chatMessageActionButton(BuildContext context, String? otherUserId) {
  final me = context.watch<AuthProvider>().currentUser;
  if (me == null ||
      otherUserId == null ||
      otherUserId.isEmpty ||
      otherUserId == me.id ||
      !me.canAccessChat ||
      !me.canStartChat ||
      !me.canMessageAnyone) {
    return null;
  }
  final l10n = AppLocalizations.of(context);
  return IconButton(
    tooltip: l10n.messageUser,
    icon: const Icon(Icons.chat_outlined),
    onPressed: () => openDirectChatWith(context, otherUserId: otherUserId),
  );
}
