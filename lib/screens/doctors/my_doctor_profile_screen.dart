import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/doctor_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/main_app_bar_actions.dart';

class MyDoctorProfileScreen extends StatefulWidget {
  const MyDoctorProfileScreen({super.key});

  @override
  State<MyDoctorProfileScreen> createState() => _MyDoctorProfileScreenState();
}

class _MyDoctorProfileScreenState extends State<MyDoctorProfileScreen> {
  final FirestoreService _firestore = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  DoctorModel? _doctor;
  late TextEditingController _specAr;
  late TextEditingController _specEn;
  late TextEditingController _qualAr;
  late TextEditingController _qualEn;
  late TextEditingController _certAr;
  late TextEditingController _certEn;
  late TextEditingController _bio;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _specAr = TextEditingController();
    _specEn = TextEditingController();
    _qualAr = TextEditingController();
    _qualEn = TextEditingController();
    _certAr = TextEditingController();
    _certEn = TextEditingController();
    _bio = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _specAr.dispose();
    _specEn.dispose();
    _qualAr.dispose();
    _qualEn.dispose();
    _certAr.dispose();
    _certEn.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    var doc = await _firestore.getDoctorByUserId(user.id);
    // If user has doctor role but no doctor doc yet (e.g. role added before ensureDoctorDocForUser), create it so the form appears and they show in Our doctors.
    if (doc == null && user.hasRole(UserRole.doctor)) {
      await _firestore.ensureDoctorDocForUser(user.id, user.displayName);
      if (!mounted) return;
      doc = await _firestore.getDoctorByUserId(user.id);
    }
    if (!mounted) return;
    setState(() {
      _doctor = doc;
      if (doc != null) {
        _specAr.text = doc.specializationAr ?? '';
        _specEn.text = doc.specializationEn ?? '';
        _qualAr.text = doc.qualificationsAr ?? '';
        _qualEn.text = doc.qualificationsEn ?? '';
        _certAr.text = doc.certificationsAr ?? '';
        _certEn.text = doc.certificationsEn ?? '';
        _bio.text = doc.bio ?? '';
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_doctor == null) return;
    setState(() => _saving = true);
    await _firestore.updateDoctor(_doctor!.id, {
      'specializationAr': _specAr.text.trim().isEmpty ? null : _specAr.text.trim(),
      'specializationEn': _specEn.text.trim().isEmpty ? null : _specEn.text.trim(),
      'qualificationsAr': _qualAr.text.trim().isEmpty ? null : _qualAr.text.trim(),
      'qualificationsEn': _qualEn.text.trim().isEmpty ? null : _qualEn.text.trim(),
      'certificationsAr': _certAr.text.trim().isEmpty ? null : _certAr.text.trim(),
      'certificationsEn': _certEn.text.trim().isEmpty ? null : _certEn.text.trim(),
      'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
    });
    setState(() => _saving = false);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.myDoctorProfile),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: [
            ...MainAppBarActions.notificationsLanguageTheme(context),
            if (_doctor != null)
              TextButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.save),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _doctor == null
                ? Center(child: Text(l10n.noData))
                : SingleChildScrollView(
                    padding: ResponsivePadding.all(context),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _specAr,
                            decoration: InputDecoration(labelText: '${l10n.specialization} (AR)'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _specEn,
                            decoration: InputDecoration(labelText: '${l10n.specialization} (EN)'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _qualAr,
                            decoration: InputDecoration(labelText: '${l10n.qualifications} (AR)'),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _qualEn,
                            decoration: InputDecoration(labelText: '${l10n.qualifications} (EN)'),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _certAr,
                            decoration: InputDecoration(labelText: '${l10n.certifications} (AR)'),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _certEn,
                            decoration: InputDecoration(labelText: '${l10n.certifications} (EN)'),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _bio,
                            decoration: const InputDecoration(labelText: 'Bio'),
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
