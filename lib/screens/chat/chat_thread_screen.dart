import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/date_format.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_conversation_model.dart';
import '../../models/chat_message_model.dart';
import '../../models/chat_settings_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_media_cache.dart';
import '../../services/chat_media_picker.dart';
import '../../services/chat_media_saver.dart';
import '../../services/chat_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/chat/chat_document_thumbnail.dart';
import '../../widgets/chat/chat_inline_audio.dart';
import '../../widgets/chat/chat_media_fullscreen_viewer.dart';
import '../../widgets/chat/chat_network_image.dart';
import '../../widgets/main_app_bar_actions.dart';

const _kReactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

class ChatThreadScreen extends StatefulWidget {
  final String conversationId;
  /// When true (tablet split view), hide back navigation chrome slightly.
  final bool embedded;

  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    this.embedded = false,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final ChatService _chat = ChatService();
  final FirestoreService _fs = FirestoreService();
  final ChatMediaPicker _picker = ChatMediaPicker();
  final ChatMediaSaver _saver = ChatMediaSaver();
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();

  ChatConversationModel? _conversation;
  Map<String, UserModel> _usersById = {};
  ChatSettingsModel _settings = ChatSettingsModel.defaults;
  bool _sending = false;
  bool _recording = false;
  ChatMessageModel? _replyTo;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _picker.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final users = await _fs.getUsers();
    final settings = await _chat.getChatSettings();
    if (!mounted) return;
    setState(() {
      _usersById = {for (final u in users) u.id: u};
      _settings = settings;
    });
    final me = context.read<AuthProvider>().currentUser;
    if (me != null) {
      await _chat.markConversationRead(
        conversationId: widget.conversationId,
        uid: me.id,
      );
    }
  }

  Future<void> _sendText(UserModel me) async {
    if (!me.canSendChatText) return;
    final t = _text.text.trim();
    if (t.isEmpty || _conversation == null) return;
    final reply = _replyTo;
    setState(() {
      _sending = true;
      _replyTo = null;
    });
    try {
      await _chat.sendText(
        conversationId: widget.conversationId,
        senderId: me.id,
        participantIds: _conversation!.participantIds,
        text: t,
        replyTo: reply,
      );
      _text.clear();
    } catch (_) {
      if (mounted) {
        setState(() => _replyTo = reply);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).chatSendFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPicked(UserModel me, ChatPickedMedia? media) async {
    if (media == null || _conversation == null) return;
    String? caption;
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chatCaptionOptional),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.typeMessage,
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.send),
          ),
        ],
      ),
    );
    caption = controller.text.trim();
    controller.dispose();
    if (ok != true || !mounted) return;

    final reply = _replyTo;
    setState(() {
      _sending = true;
      _replyTo = null;
    });
    try {
      await _chat.sendMedia(
        conversationId: widget.conversationId,
        senderId: me.id,
        participantIds: _conversation!.participantIds,
        media: media,
        caption: caption.isEmpty ? null : caption,
        replyTo: reply,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _replyTo = reply);
      final msg = e.toString().contains('file_too_large')
          ? l10n.chatFileTooLarge
          : l10n.chatSendFailed;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showAttach(UserModel me) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              if (me.canSendChatImage)
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: Text(l10n.chatCameraPhoto),
                  onTap: () async {
                    // Pick while sheet is open so the browser keeps the user gesture.
                    final media = await _picker.pickCameraPhoto(me);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) await _sendPicked(me, media);
                  },
                ),
              if (me.canSendChatVideo)
                ListTile(
                  leading: const Icon(Icons.videocam),
                  title: Text(l10n.chatCameraVideo),
                  onTap: () async {
                    final media = await _picker.pickCameraVideo(me);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) await _sendPicked(me, media);
                  },
                ),
              if (me.canSendChatImage || me.canSendChatVideo)
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(l10n.chatGallery),
                  onTap: () async {
                    final media = await _picker.pickGallery(me);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) await _sendPicked(me, media);
                  },
                ),
              if (me.canSendChatDocument)
                ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: Text(l10n.chatDocument),
                  onTap: () async {
                    final media = await _picker.pickDocument(me);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) await _sendPicked(me, media);
                  },
                ),
              if (me.canSendChatAudio)
                ListTile(
                  leading: const Icon(Icons.audio_file),
                  title: Text(l10n.chatAudioFile),
                  onTap: () async {
                    final media = await _picker.pickAudioFile(me);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) await _sendPicked(me, media);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleVoice(UserModel me) async {
    final l10n = AppLocalizations.of(context);
    if (_recording) {
      final media = await _picker.stopVoiceRecording();
      setState(() => _recording = false);
      await _sendPicked(me, media);
      return;
    }
    final ok = await _picker.startVoiceRecording(me);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.generalErrorMessage('errorPermissionDenied'))),
        );
      }
      return;
    }
    setState(() => _recording = true);
  }

  Future<void> _saveMedia(ChatMessageModel m, UserModel me) async {
    final l10n = AppLocalizations.of(context);
    try {
      final ok = await _saver.saveMessageMedia(m, me);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? l10n.chatMediaSaved : l10n.chatMediaSaveFailed)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatMediaSaveFailed)),
      );
    }
  }

  String _conversationTitle(ChatConversationModel? c, UserModel me, AppLocalizations l10n) {
    if (c == null) return l10n.messages;
    if (c.isMultiParty && (c.title?.isNotEmpty ?? false)) {
      return c.title!;
    }
    final otherId = c.otherParticipantId(me.id);
    return _usersById[otherId]?.displayName ?? c.title ?? l10n.messages;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = context.watch<AuthProvider>().currentUser;
    if (me == null || !me.canAccessChat) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.messages)),
        body: Center(child: Text(l10n.generalErrorMessage('errorPermissionDenied'))),
      );
    }

    final compact = Breakpoint.isCompact(context) || Breakpoint.isExtraSmall(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);

    return Directionality(
      textDirection: l10n.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: widget.embedded
            ? null
            : AppBar(
          title: StreamBuilder<ChatConversationModel?>(
            stream: _chat.conversationStream(widget.conversationId),
            builder: (context, snap) {
              final c = snap.data;
              if (c != null && _conversation?.id != c.id) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _conversation = c);
                });
              } else if (c != null) {
                _conversation = c;
              }
              final name = _conversationTitle(c, me, l10n);
              final subtitle = c != null && c.isMultiParty
                  ? '${c.participantIds.length}'
                  : null;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              );
            },
          ),
          actions: [
            if (_conversation?.type == ChatConversationType.group)
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: l10n.chatGroupInfo,
                onPressed: () => context.push('/chat/${widget.conversationId}/info'),
              ),
            if (me.canDeleteChat &&
                (_conversation?.participantIds.contains(me.id) == true ||
                    me.canDeleteAnyChat))
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.chatDeleteChat,
                onPressed: () async {
                  final c = _conversation;
                  if (c == null) return;
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
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true || !mounted) return;
                  try {
                    await _chat.deleteConversation(widget.conversationId);
                    if (mounted) {
                      if (widget.embedded) {
                        context.go('/chat');
                      } else if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/chat');
                      }
                    }
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.generalErrorMessage('errorSaveFailed'),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ...MainAppBarActions.notificationsLanguageTheme(context),
          ],
        ),
        body: Column(
          children: [
            if (widget.embedded)
              StreamBuilder<ChatConversationModel?>(
                stream: _chat.conversationStream(widget.conversationId),
                builder: (context, snap) {
                  final c = snap.data;
                  if (c != null) _conversation = c;
                  return Material(
                    elevation: 1,
                    child: ListTile(
                      dense: true,
                      title: Text(
                        _conversationTitle(c, me, l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: c != null && c.isMultiParty
                          ? Text('${c.participantIds.length}')
                          : null,
                      trailing: c?.type == ChatConversationType.group
                          ? IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () => context.push(
                                '/chat/${widget.conversationId}/info',
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
            Expanded(
              child: StreamBuilder<List<ChatMessageModel>>(
                stream: _chat.messagesStream(
                  widget.conversationId,
                  retentionCutoff: _settings.retentionCutoff(),
                ),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('${l10n.generalErrorMessage('errorLoadFailed')}\n${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snap.data!;
                  if (messages.isEmpty) {
                    return Center(child: Text(l10n.chatNoConversations));
                  }
                  final multi = _conversation?.isMultiParty == true;
                  return ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: responsiveListPadding(context),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final mine = m.senderId == me.id;
                      final systemText = m.type == ChatMessageType.system
                          ? switch (m.text) {
                              'group_created' => l10n.chatGroupCreated,
                              'group_renamed' => l10n.chatGroupRenamed,
                              'group_members_added' => l10n.chatGroupMembersAdded,
                              'group_member_removed' => l10n.chatGroupMemberRemoved,
                              _ => m.text,
                            }
                          : m.text;
                      return _MessageBubble(
                        message: m.type == ChatMessageType.system
                            ? m.copyWith(text: systemText)
                            : m,
                        mine: mine,
                        myUid: me.id,
                        showSenderName: multi && !mine,
                        senderName: _usersById[m.senderId]?.displayName,
                        replySenderName: m.replyToSenderId != null
                            ? _usersById[m.replyToSenderId!]?.displayName
                            : null,
                        canSave: me.canSaveChatMedia && m.hasMedia,
                        canDelete: me.canDeleteAnyChat || mine,
                        canReact: m.type != ChatMessageType.system,
                        canReply: m.type != ChatMessageType.system &&
                            me.canSendChatText,
                        onSave: () => _saveMedia(m, me),
                        onDelete: () async {
                          await _chat.deleteMessage(
                            conversationId: widget.conversationId,
                            messageId: m.id,
                          );
                        },
                        onReply: () => setState(() => _replyTo = m),
                        onReact: (emoji) async {
                          await _chat.toggleReaction(
                            conversationId: widget.conversationId,
                            messageId: m.id,
                            uid: me.id,
                            emoji: emoji,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            if (_sending) const LinearProgressIndicator(minHeight: 2),
            if (_replyTo != null)
              Material(
                color: theme.colorScheme.surfaceContainerHighest,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.reply),
                  title: Text(
                    '${l10n.chatReplyingTo} ${_usersById[_replyTo!.senderId]?.displayName ?? ''}'
                        .trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _replyTo!.text?.trim().isNotEmpty == true
                        ? _replyTo!.text!
                        : (_replyTo!.fileName ?? _replyTo!.type.value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _replyTo = null),
                  ),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 4 : 8,
                  4,
                  compact ? 4 : 8,
                  8 + (bottomInset > 0 ? 0 : 0),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (me.canSendChatImage ||
                        me.canSendChatVideo ||
                        me.canSendChatDocument ||
                        me.canSendChatAudio)
                      IconButton(
                        visualDensity: compact
                            ? VisualDensity.compact
                            : VisualDensity.standard,
                        tooltip: l10n.chatAttach,
                        onPressed: _sending ? null : () => _showAttach(me),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    if (me.canSendChatVoice)
                      IconButton(
                        visualDensity: compact
                            ? VisualDensity.compact
                            : VisualDensity.standard,
                        tooltip: _recording
                            ? l10n.chatStopRecording
                            : l10n.chatVoiceMessage,
                        color: _recording ? Colors.red : null,
                        onPressed: _sending ? null : () => _toggleVoice(me),
                        icon: Icon(_recording ? Icons.stop_circle : Icons.mic),
                      ),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        enabled: me.canSendChatText && !_sending,
                        minLines: 1,
                        maxLines: compact ? 3 : 5,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: l10n.typeMessage,
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: compact ? 10 : 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendText(me),
                      ),
                    ),
                    IconButton(
                      visualDensity: compact
                          ? VisualDensity.compact
                          : VisualDensity.standard,
                      onPressed: _sending || !me.canSendChatText
                          ? null
                          : () => _sendText(me),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool mine;
  final String myUid;
  final bool showSenderName;
  final String? senderName;
  final String? replySenderName;
  final bool canSave;
  final bool canDelete;
  final bool canReact;
  final bool canReply;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final VoidCallback onReply;
  final ValueChanged<String> onReact;

  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.myUid,
    this.showSenderName = false,
    required this.senderName,
    this.replySenderName,
    required this.canSave,
    required this.canDelete,
    required this.canReact,
    required this.canReply,
    required this.onSave,
    required this.onDelete,
    required this.onReply,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = mine
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final when = message.createdAt != null
        ? AppDateFormat.shortDateTimeSec.format(message.createdAt!)
        : '';
    final w = MediaQuery.sizeOf(context).width;
    final maxBubble = Breakpoint.isDesktop(context)
        ? (w * 0.28).clamp(220.0, 320.0)
        : Breakpoint.isTablet(context)
            ? (w * 0.42).clamp(220.0, 340.0)
            : (w * 0.72).clamp(180.0, 300.0);
    final isMediaOnly = message.type == ChatMessageType.image ||
        message.type == ChatMessageType.video;

    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubble),
        child: Card(
          color: bg,
          margin: const EdgeInsets.symmetric(vertical: 4),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            onLongPress: () => _menu(context),
            behavior: HitTestBehavior.deferToChild,
            child: Padding(
              padding: EdgeInsets.all(isMediaOnly ? 4 : 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSenderName && (senderName?.isNotEmpty ?? false))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                      child: Text(
                        senderName!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (message.replyToId != null) ...[
                    Container(
                      margin: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                        border: Border(
                          left: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((replySenderName ?? '').isNotEmpty)
                            Text(
                              replySenderName!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          Text(
                            message.replyToText ?? message.replyToType ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                  _body(context, maxBubble),
                  if (message.reactions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: message.reactions.entries.map((e) {
                          final mineReact = e.value.contains(myUid);
                          return InkWell(
                            onTap: canReact ? () => onReact(e.key) : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: mineReact
                                    ? theme.colorScheme.primary
                                        .withValues(alpha: 0.18)
                                    : theme.colorScheme.surface
                                        .withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: mineReact
                                      ? theme.colorScheme.primary
                                      : theme.dividerColor,
                                ),
                              ),
                              child: Text(
                                '${e.key} ${e.value.length}',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  if (when.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isMediaOnly ? 6 : 0,
                        0,
                        isMediaOnly ? 6 : 0,
                        isMediaOnly ? 4 : 0,
                      ),
                      child: Text(when, style: theme.textTheme.labelSmall),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, double maxBubble) {
    switch (message.type) {
      case ChatMessageType.image:
        final url = message.mediaUrl;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (url != null)
              GestureDetector(
                onTap: () => ChatMediaFullscreenViewer.open(
                  context,
                  url: url,
                  heroTag: 'chat-img-${message.id}',
                ),
                child: Hero(
                  tag: 'chat-img-${message.id}',
                  child: ChatNetworkImage(
                    url: url,
                    maxWidth: maxBubble - 8,
                    maxHeight: 280,
                    fit: BoxFit.contain,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            if (message.text?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                child: Text(message.text!),
              ),
          ],
        );
      case ChatMessageType.video:
        return message.mediaUrl == null
            ? const SizedBox.shrink()
            : ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxBubble - 8,
                  maxHeight: 280,
                ),
                child: _InlineVideo(
                  url: message.mediaUrl!,
                  messageId: message.id,
                ),
              );
      case ChatMessageType.audio:
      case ChatMessageType.voice:
        return message.mediaUrl == null
            ? const SizedBox.shrink()
            : ChatInlineAudio(
                url: message.mediaUrl!,
                mimeType: message.mimeType,
              );
      case ChatMessageType.document:
        return Padding(
          padding: const EdgeInsets.all(6),
          child: _DocumentTile(message: message),
        );
      case ChatMessageType.system:
        return Text(
          message.text ?? '',
          style: const TextStyle(fontStyle: FontStyle.italic),
        );
      case ChatMessageType.text:
        return Text(message.text ?? '');
    }
  }

  Future<void> _menu(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canReact)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _kReactionEmojis.map((emoji) {
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        onReact(emoji);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (canReply)
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text(l10n.chatReply),
                onTap: () {
                  Navigator.pop(ctx);
                  onReply();
                },
              ),
            if (canSave)
              ListTile(
                leading: const Icon(Icons.download),
                title: Text(l10n.chatSaveMedia),
                onTap: () {
                  Navigator.pop(ctx);
                  onSave();
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.delete),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final ChatMessageModel message;
  const _DocumentTile({required this.message});

  Future<void> _open(BuildContext context) async {
    final url = message.mediaUrl;
    if (url == null) return;
    final l10n = AppLocalizations.of(context);
    final ok = await ChatMediaCache.instance.openInExternalApp(
      url,
      fileName: message.fileName,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatOpenDocumentFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          ChatDocumentThumbnail(message: message),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.fileName ?? 'document',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  AppLocalizations.of(context).chatOpenDocument,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).chatOpenDocument,
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _open(context),
          ),
        ],
      ),
    );
  }
}

class _InlineVideo extends StatefulWidget {
  final String url;
  final String messageId;
  const _InlineVideo({required this.url, required this.messageId});

  @override
  State<_InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<_InlineVideo> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }).catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return GestureDetector(
      onTap: () => ChatMediaFullscreenViewer.open(
        context,
        url: widget.url,
        isVideo: true,
        heroTag: 'chat-vid-${widget.messageId}',
      ),
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio == 0
            ? 16 / 9
            : _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            const Icon(
              Icons.play_circle_fill,
              size: 48,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
