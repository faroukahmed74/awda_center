import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/main_app_bar_actions.dart';

class ChatNewScreen extends StatefulWidget {
  const ChatNewScreen({super.key});

  @override
  State<ChatNewScreen> createState() => _ChatNewScreenState();
}

class _ChatNewScreenState extends State<ChatNewScreen> {
  final FirestoreService _fs = FirestoreService();
  final ChatService _chat = ChatService();
  final TextEditingController _search = TextEditingController();
  List<UserModel> _users = [];
  bool _loading = true;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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

  Future<void> _openWith(UserModel other) async {
    final me = context.read<AuthProvider>().currentUser;
    if (me == null || !me.canStartChat || !me.canMessageAnyone) return;
    if (other.id == me.id) return;
    setState(() => _opening = true);
    try {
      final conv = await _chat.getOrCreateDirect(myUid: me.id, otherUid: other.id);
      if (!mounted) return;
      context.pushReplacement('/chat/${conv.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).chatSendFailed)),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = context.watch<AuthProvider>().currentUser;
    if (me == null || !me.canAccessChat || !me.canStartChat) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.newChat)),
        body: Center(child: Text(l10n.generalErrorMessage('errorPermissionDenied'))),
      );
    }

    final q = _search.text.trim().toLowerCase();
    final filtered = _users.where((u) {
      if (u.id == me.id) return false;
      if (q.isEmpty) return true;
      return u.displayName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (u.phone ?? '').contains(q) ||
          (u.phone2 ?? '').contains(q);
    }).toList();

    return Directionality(
      textDirection: l10n.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.newChat),
          actions: MainAppBarActions.notificationsLanguageTheme(context),
        ),
        body: _opening
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: responsiveMaxContentWidth(context).isFinite
                        ? responsiveMaxContentWidth(context)
                        : 720,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: ResponsivePadding.all(context),
                        child: TextField(
                          controller: _search,
                          decoration: InputDecoration(
                            hintText: l10n.chatSearchUsers,
                            prefixIcon: const Icon(Icons.search),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
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
                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Text(
                                        u.displayName.isNotEmpty
                                            ? u.displayName.characters.first
                                            : '?',
                                      ),
                                    ),
                                    title: Text(u.displayName),
                                    subtitle: Text(
                                      '${u.roleValue}${u.email.isNotEmpty ? ' · ${u.email}' : ''}',
                                    ),
                                    onTap: () => _openWith(u),
                                  );
                                },
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
