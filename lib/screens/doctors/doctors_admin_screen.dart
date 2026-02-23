import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/doctor_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

/// Admin: List doctors, add (link user with doctor role), edit.
class DoctorsAdminScreen extends StatefulWidget {
  const DoctorsAdminScreen({super.key});

  @override
  State<DoctorsAdminScreen> createState() => _DoctorsAdminScreenState();
}

class _DoctorsAdminScreenState extends State<DoctorsAdminScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<DoctorModel> _doctors = [];
  List<UserModel> _usersWithDoctorRole = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final doctors = await _firestore.getDoctors();
    final users = await _firestore.getUsers();
    final withDoctor = users.where((u) => u.hasRole(UserRole.doctor)).toList();
    setState(() {
      _doctors = doctors;
      _usersWithDoctorRole = withDoctor;
      _loading = false;
    });
  }

  Future<void> _showEditDoctor(BuildContext context, AppLocalizations l10n, DoctorModel doc) async {
    final specAr = TextEditingController(text: doc.specializationAr ?? '');
    final specEn = TextEditingController(text: doc.specializationEn ?? '');
    final qualAr = TextEditingController(text: doc.qualificationsAr ?? '');
    final qualEn = TextEditingController(text: doc.qualificationsEn ?? '');
    final bio = TextEditingController(text: doc.bio ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editProfile),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: specAr, decoration: InputDecoration(labelText: '${l10n.specialization} (AR)'), maxLines: 2),
              const SizedBox(height: 8),
              TextField(controller: specEn, decoration: InputDecoration(labelText: '${l10n.specialization} (EN)'), maxLines: 2),
              const SizedBox(height: 8),
              TextField(controller: qualAr, decoration: InputDecoration(labelText: '${l10n.qualifications} (AR)'), maxLines: 2),
              const SizedBox(height: 8),
              TextField(controller: qualEn, decoration: InputDecoration(labelText: '${l10n.qualifications} (EN)'), maxLines: 2),
              const SizedBox(height: 8),
              TextField(controller: bio, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () async {
              await _firestore.updateDoctor(doc.id, {
                'specializationAr': specAr.text.trim().isEmpty ? null : specAr.text.trim(),
                'specializationEn': specEn.text.trim().isEmpty ? null : specEn.text.trim(),
                'qualificationsAr': qualAr.text.trim().isEmpty ? null : qualAr.text.trim(),
                'qualificationsEn': qualEn.text.trim().isEmpty ? null : qualEn.text.trim(),
                'bio': bio.text.trim().isEmpty ? null : bio.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Future<void> _addDoctor(BuildContext context, AppLocalizations l10n) async {
    final usersWithoutDoc = _usersWithDoctorRole.where((u) {
      return !_doctors.any((d) => d.userId == u.id);
    }).toList();
    if (usersWithoutDoc.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No users with doctor role left to add. Invite or assign doctor role first.')));
      return;
    }
    String? selectedId;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addDoctor),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: usersWithoutDoc.map((u) => ListTile(title: Text(u.displayName), subtitle: Text(u.email), onTap: () { selectedId = u.id; Navigator.pop(ctx); })).toList(),
          ),
        ),
      ),
    );
    if (selectedId != null) {
      final u = _usersWithDoctorRole.firstWhere((e) => e.id == selectedId);
      await _firestore.ensureDoctorDocForUser(u.id, u.displayName);
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
          title: Text(l10n.manageDoctors),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
          actions: [
            IconButton(icon: const Icon(Icons.add), tooltip: l10n.addDoctor, onPressed: () => _addDoctor(context, l10n)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _doctors.isEmpty
                    ? Center(child: Text(l10n.noData))
                    : ListView.builder(
                        padding: responsiveListPadding(context),
                        itemCount: _doctors.length,
                        itemBuilder: (context, i) {
                          final d = _doctors[i];
                          UserModel? user;
                            for (final x in _usersWithDoctorRole) {
                              if (x.id == d.userId) { user = x; break; }
                            }
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(d.displayName ?? user?.displayName ?? d.userId),
                              subtitle: Text([d.specializationAr ?? d.specializationEn, user?.email].where((e) => e != null && e.toString().isNotEmpty).join(' • ')),
                              trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEditDoctor(context, l10n, d)),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
