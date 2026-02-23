import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audit_log_model.dart';
import '../../services/firestore_service.dart';
import 'package:intl/intl.dart' hide TextDirection;

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
    setState(() {
      _list = list;
      _loading = false;
    });
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
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
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
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('${e.action} • ${e.entityType}'),
                              subtitle: Text('${e.userEmail ?? e.userId} • ${e.createdAt != null ? DateFormat.yMd().add_Hm().format(e.createdAt!) : ''}'),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
