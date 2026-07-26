import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/main_app_bar_actions.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  final ChatService _chat = ChatService();
  final TextEditingController _days = TextEditingController();
  final TextEditingController _quietStart = TextEditingController();
  final TextEditingController _quietEnd = TextEditingController();
  bool _quietEnabled = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _days.dispose();
    _quietStart.dispose();
    _quietEnd.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await _chat.getChatSettings();
    if (!mounted) return;
    _days.text = '${s.retentionDays}';
    _quietStart.text = '${s.quietHoursStart}';
    _quietEnd.text = '${s.quietHoursEnd}';
    _quietEnabled = s.quietHoursEnabled;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || !user.canManageChatRetention) return;
    final days = int.tryParse(_days.text.trim()) ?? 0;
    final qs = (int.tryParse(_quietStart.text.trim()) ?? 22).clamp(0, 23);
    final qe = (int.tryParse(_quietEnd.text.trim()) ?? 8).clamp(0, 23);
    setState(() => _saving = true);
    try {
      await _chat.saveChatSettings(
        retentionDays: days,
        updatedBy: user.id,
        quietHoursStart: qs,
        quietHoursEnd: qe,
        quietHoursEnabled: _quietEnabled,
      );
      AuditService.log(
        action: 'chat_retention_updated',
        entityType: 'app_settings',
        entityId: 'chat',
        userId: user.id,
        userEmail: user.email,
        details: {
          'retentionDays': days,
          'quietHoursEnabled': _quietEnabled,
          'quietHoursStart': qs,
          'quietHoursEnd': qe,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).saved)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).generalErrorMessage('errorSaveFailed'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null || !user.canAccessChatSettings) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.chatSettings)),
        body: Center(child: Text(l10n.generalErrorMessage('errorPermissionDenied'))),
      );
    }

    return Directionality(
      textDirection: l10n.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.chatSettings),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/chat');
              }
            },
          ),
          actions: MainAppBarActions.notificationsLanguageTheme(context),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    l10n.chatRetentionTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.chatRetentionHint),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _days,
                    enabled: user.canManageChatRetention,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.chatRetentionDays,
                      border: const OutlineInputBorder(),
                      helperText: l10n.chatRetentionZeroUnlimited,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.chatQuietHours,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.chatQuietHoursHint),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.chatQuietHours),
                    value: _quietEnabled,
                    onChanged: user.canManageChatRetention
                        ? (v) => setState(() => _quietEnabled = v)
                        : null,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _quietStart,
                          enabled: user.canManageChatRetention && _quietEnabled,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.chatQuietStart,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _quietEnd,
                          enabled: user.canManageChatRetention && _quietEnabled,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.chatQuietEnd,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (user.canManageChatRetention)
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.save),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.chatPrivacyNotice,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }
}
