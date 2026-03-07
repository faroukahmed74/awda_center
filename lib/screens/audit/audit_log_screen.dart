import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audit_log_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/notifications_button.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/date_format.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<AuditLogModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _firestore.getAuditLogs();
    list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  String _auditActionLabel(String action, String entityType, String? entityId, Map<String, dynamic>? details) {
    final parts = <String>[];
    if (action.isNotEmpty) parts.add(action.replaceAll('_', ' '));
    if (entityType.isNotEmpty) parts.add('($entityType)');
    if (entityId != null && entityId.isNotEmpty) parts.add('· $entityId');
    if (details != null && details.isNotEmpty) {
      final d = details.entries.map((e) => '${e.key}: ${e.value}').take(2).join(', ');
      if (d.isNotEmpty) parts.add('· $d');
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.auditLog),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: const [NotificationsButton()],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _list.isEmpty
                    ? Center(child: Text(l10n.noData))
                    : ListView.builder(
                        padding: responsiveListPadding(context),
                        itemCount: _list.length,
                        itemBuilder: (context, i) {
                          final e = _list[i];
                          final when = e.createdAt != null ? AppDateFormat.shortDateTime.format(e.createdAt!) : '';
                          final who = e.userEmail ?? e.userId;
                          final what = _auditActionLabel(e.action, e.entityType, e.entityId, e.details);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(what, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${l10n.auditWho}: $who'),
                                  Text('${l10n.auditWhen}: $when'),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
