import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/room_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/notifications_button.dart';

/// Admin: Rooms CRUD.
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<RoomModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _firestore.getAllRooms();
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  Future<void> _showForm(BuildContext context, AppLocalizations l10n, [RoomModel? existing]) async {
    final nameAr = TextEditingController(text: existing?.nameAr ?? '');
    final nameEn = TextEditingController(text: existing?.nameEn ?? '');
    final roomType = TextEditingController(text: existing?.roomType ?? '');
    var isActive = existing?.isActive ?? true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? l10n.addRoom : l10n.editRoom),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameAr, decoration: const InputDecoration(labelText: 'Name (Arabic)')),
                const SizedBox(height: 8),
                TextField(controller: nameEn, decoration: const InputDecoration(labelText: 'Name (English)')),
                const SizedBox(height: 8),
                TextField(controller: roomType, decoration: const InputDecoration(labelText: 'Room type')),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: Text(l10n.active),
                  value: isActive,
                  onChanged: (v) => setState(() => isActive = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () async {
                if (existing != null) {
                  await _firestore.updateRoom(existing.id, {
                    'nameAr': nameAr.text.trim().isEmpty ? null : nameAr.text.trim(),
                    'nameEn': nameEn.text.trim().isEmpty ? null : nameEn.text.trim(),
                    'roomType': roomType.text.trim().isEmpty ? null : roomType.text.trim(),
                    'isActive': isActive,
                  });
                } else {
                  await _firestore.addRoom(RoomModel(
                    id: '',
                    nameAr: nameAr.text.trim().isEmpty ? null : nameAr.text.trim(),
                    nameEn: nameEn.text.trim().isEmpty ? null : nameEn.text.trim(),
                    roomType: roomType.text.trim().isEmpty ? null : roomType.text.trim(),
                    isActive: isActive,
                  ));
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(RoomModel r, BuildContext context, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConfirm),
        content: Text('${l10n.room}: ${r.displayName}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
        ],
      ),
    );
    if (ok == true) {
      await _firestore.deleteRoom(r.id);
      if (mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.rooms),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: [
            const NotificationsButton(),
            IconButton(icon: const Icon(Icons.add), tooltip: l10n.addRoom, onPressed: () => _showForm(context, l10n)),
          ],
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
                          final r = _list[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(r.displayName),
                              subtitle: Text([r.roomType, r.isActive ? l10n.active : l10n.inactive].where((e) => e != null && e.isNotEmpty).join(' • ')),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(context, l10n, r)),
                                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(r, context, l10n)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
