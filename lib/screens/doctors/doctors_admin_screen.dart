import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/doctor_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/notifications_button.dart';
import 'add_doctor_dialog.dart';

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
    final certAr = TextEditingController(text: doc.certificationsAr ?? '');
    final certEn = TextEditingController(text: doc.certificationsEn ?? '');
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
              TextField(controller: certAr, decoration: InputDecoration(labelText: '${l10n.certifications} (AR)'), maxLines: 2),
              const SizedBox(height: 8),
              TextField(controller: certEn, decoration: InputDecoration(labelText: '${l10n.certifications} (EN)'), maxLines: 2),
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
                'certificationsAr': certAr.text.trim().isEmpty ? null : certAr.text.trim(),
                'certificationsEn': certEn.text.trim().isEmpty ? null : certEn.text.trim(),
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

  Future<void> _onAddDoctorPressed(BuildContext context, AppLocalizations l10n) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addDoctor),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add),
              title: Text(l10n.inviteNewDoctor),
              subtitle: Text(l10n.inviteNewDoctorHint),
              onTap: () => Navigator.pop(ctx, 'invite'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(l10n.linkExistingUser),
              subtitle: Text(l10n.linkExistingUserDoctorHint),
              onTap: () => Navigator.pop(ctx, 'link'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'invite') {
      final ok = await showDialog<bool>(context: context, builder: (_) => const AddDoctorDialog());
      if (ok == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.inviteSent)));
        _load();
      }
    } else if (choice == 'link') {
      await _addDoctorLinkExisting(context, l10n);
    }
  }

  Future<void> _addDoctorLinkExisting(BuildContext context, AppLocalizations l10n) async {
    final usersWithoutDoc = _usersWithDoctorRole.where((u) {
      return !_doctors.any((d) => d.userId == u.id);
    }).toList();
    if (usersWithoutDoc.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.noUsersWithDoctorRoleToLink)));
      return;
    }
    String? selectedId;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.linkExistingUser),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: usersWithoutDoc.map((u) => ListTile(title: Text(u.displayName), subtitle: Text(u.email), onTap: () { selectedId = u.id; Navigator.pop(ctx); })).toList(),
          ),
        ),
      ),
    );
    if (selectedId != null && mounted) {
      final u = _usersWithDoctorRole.firstWhere((e) => e.id == selectedId);
      await _firestore.ensureDoctorDocForUser(u.id, u.displayName);
      _load();
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
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: [
            const NotificationsButton(),
            IconButton(icon: const Icon(Icons.add), tooltip: l10n.addDoctor, onPressed: () => _onAddDoctorPressed(context, l10n)),
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
