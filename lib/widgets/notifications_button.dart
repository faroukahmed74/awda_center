import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../l10n/app_localizations.dart';
import '../models/app_notification.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/in_app_notifications_service.dart';

/// App bar icon that opens a responsive notifications panel (role-based: appointments, audit, todos).
class NotificationsButton extends StatelessWidget {
  const NotificationsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final l10n = AppLocalizations.of(context);

    return IconButton(
      icon: const Icon(Icons.notifications_outlined),
      tooltip: l10n.notifications,
      onPressed: user == null
          ? null
          : () => _openNotificationsPanel(context, user),
    );
  }

  void _openNotificationsPanel(BuildContext context, UserModel user) {
    final isWide = MediaQuery.sizeOf(context).width >= Breakpoint.tablet;
    if (isWide) {
      showDialog<void>(
        context: context,
        builder: (ctx) => _NotificationsPanel(user: user),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) => _NotificationsPanel(
            user: user,
            scrollController: scrollController,
          ),
        ),
      );
    }
  }
}

class _NotificationsPanel extends StatefulWidget {
  final UserModel user;
  final ScrollController? scrollController;

  const _NotificationsPanel({required this.user, this.scrollController});

  @override
  State<_NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<_NotificationsPanel> {
  final InAppNotificationsService _service = InAppNotificationsService();
  List<AppNotification>? _list;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getNotifications(widget.user);
      if (mounted) {
        setState(() {
          _list = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget content;
    if (_loading) {
      content = const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    } else if (_error != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    } else if (_list == null || _list!.isEmpty) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none, size: 56, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                l10n.noNotifications,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      content = ListView.builder(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _list!.length,
        itemBuilder: (context, index) {
          final n = _list![index];
          return _NotificationTile(
            notification: n,
            onTap: () {
              Navigator.of(context).pop();
              if (n.route != null) context.push(n.route!);
            },
          );
        },
      );
    }

    final isDialog = widget.scrollController == null;
    final panel = Column(
      mainAxisSize: isDialog ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Icon(Icons.notifications, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.notifications,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (!_loading && (_list?.isNotEmpty ?? false))
                Text(
                  '${_list!.length}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(child: content),
      ],
    );

    if (isDialog) {
      return AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: panel,
        ),
      );
    }

    return panel;
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    IconData icon;
    switch (notification.type) {
      case AppNotificationType.appointment:
        icon = Icons.calendar_today;
        break;
      case AppNotificationType.audit:
        icon = Icons.history;
        break;
      case AppNotificationType.todo:
        icon = Icons.task_alt;
        break;
    }
    final timeStr = DateFormat.MMMd().add_Hm().format(notification.time);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              radius: 22,
              child: Icon(icon, color: theme.colorScheme.onPrimaryContainer, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notification.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      notification.subtitle,
                      style: theme.textTheme.bodySmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
