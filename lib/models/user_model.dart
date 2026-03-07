import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_permissions.dart';

enum UserRole { admin, doctor, patient, secretary, trainee }

extension UserRoleExt on UserRole {
  String get value => name;
  static UserRole fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'admin': return UserRole.admin;
      case 'doctor': return UserRole.doctor;
      case 'patient': return UserRole.patient;
      case 'secretary': return UserRole.secretary;
      case 'trainee': return UserRole.trainee;
      default: return UserRole.patient;
    }
  }
}

class UserModel {
  final String id;
  final String email;
  final String? fullNameAr;
  final String? fullNameEn;
  final String? phone;
  /// Multiple roles: e.g. ['admin', 'doctor']. Default new user: ['patient'].
  final List<String> roles;
  /// Optional: admin-set privileges. If non-empty, access uses these instead of role defaults.
  final List<String> permissions;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// Preferred language for notifications: 'en' or 'ar'. Set by app from current locale.
  final String? locale;
  /// Optional: mark patient as starred (VIP); same star icon as "new patient". Admin can set via edit user.
  final bool isStarred;
  /// Patient ID code: simple symmetric number for staff to search and for patient to share (e.g. when booking).
  final String? patientCode;

  const UserModel({
    required this.id,
    required this.email,
    this.fullNameAr,
    this.fullNameEn,
    this.phone,
    this.roles = const ['patient'],
    this.permissions = const [],
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.locale,
    this.isStarred = false,
    this.patientCode,
  });

  /// Primary role for display (first in list).
  UserRole get role => roles.isNotEmpty
      ? UserRoleExt.fromString(roles.first)
      : UserRole.patient;

  /// Display value of primary role.
  String get roleValue => role.value;

  bool hasRole(UserRole r) => roles.contains(r.value);
  bool hasAnyRole(List<UserRole> rlist) => rlist.any((r) => roles.contains(r.value));

  /// True if user can access the given feature (path or key). Uses permissions if set, else role defaults.
  bool canAccessFeature(String pathOrKey) {
    final key = pathOrKey.startsWith('/') ? pathToFeatureKey(pathOrKey) : pathOrKey;
    if (key == null) return false;
    if (permissions.isNotEmpty) return permissions.contains(key);
    for (final r in roles) {
      if (defaultFeaturesForRole(r).contains(key)) return true;
    }
    return false;
  }

  bool get canAccessAdminDashboard => canAccessFeature('admin_dashboard');
  bool get canAccessUsers => canAccessFeature('users');
  bool get canAccessAppointments => canAccessFeature('appointments');
  bool get canAccessPatients => canAccessFeature('patients');
  bool get canAccessIncomeExpenses => canAccessFeature('income_expenses');
  bool get canAccessReports => canAccessFeature('reports');
  bool get canAccessRequirements => canAccessFeature('requirements');
  bool get canAccessAdminTodos => canAccessFeature('admin_todos');

  String get displayName {
    if (fullNameAr != null && fullNameAr!.isNotEmpty) return fullNameAr!;
    if (fullNameEn != null && fullNameEn!.isNotEmpty) return fullNameEn!;
    return email;
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    List<String> rolesList = const [];
    if (d['roles'] != null && d['roles'] is List) {
      rolesList = (d['roles'] as List).map((e) => e.toString()).toList();
    } else if (d['role'] != null) {
      rolesList = [d['role'] as String];
    } else {
      rolesList = ['patient'];
    }
    List<String> permList = const [];
    if (d['permissions'] != null && d['permissions'] is List) {
      permList = (d['permissions'] as List).map((e) => e.toString()).toList();
    }
    return UserModel(
      id: doc.id,
      email: d['email'] as String? ?? '',
      fullNameAr: d['fullNameAr'] as String?,
      fullNameEn: d['fullNameEn'] as String?,
      phone: d['phone'] as String?,
      roles: rolesList,
      permissions: permList,
      isActive: d['isActive'] as bool? ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      locale: d['locale'] as String?,
      isStarred: d['isStarred'] as bool? ?? false,
      patientCode: d['patientCode'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullNameAr': fullNameAr,
      'fullNameEn': fullNameEn,
      'phone': phone,
      'roles': roles,
      'permissions': permissions,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isStarred': isStarred,
      'patientCode': patientCode,
    };
  }

  UserModel copyWith({
    String? fullNameAr,
    String? fullNameEn,
    String? phone,
    List<String>? roles,
    List<String>? permissions,
    bool? isActive,
    bool? isStarred,
    String? patientCode,
  }) {
    return UserModel(
      id: id,
      email: email,
      fullNameAr: fullNameAr ?? this.fullNameAr,
      fullNameEn: fullNameEn ?? this.fullNameEn,
      phone: phone ?? this.phone,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      locale: locale,
      isStarred: isStarred ?? this.isStarred,
      patientCode: patientCode ?? this.patientCode,
    );
  }
}
