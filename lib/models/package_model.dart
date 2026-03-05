import 'package:cloud_firestore/cloud_firestore.dart';

/// A package bundles specific services for a number of sessions at a fixed amount.
class PackageModel {
  final String id;
  final String? nameAr;
  final String? nameEn;
  /// Service document ids included in this package.
  final List<String> serviceIds;
  /// How many sessions the package covers.
  final int numberOfSessions;
  /// Total amount for the package.
  final double amount;
  final bool isActive;

  const PackageModel({
    required this.id,
    this.nameAr,
    this.nameEn,
    this.serviceIds = const [],
    this.numberOfSessions = 1,
    this.amount = 0,
    this.isActive = true,
  });

  String get displayName => (nameAr?.isNotEmpty == true) ? nameAr! : (nameEn ?? id);

  factory PackageModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final serviceIdsList = d['serviceIds'];
    final list = serviceIdsList is List ? serviceIdsList.map((e) => e.toString()).toList() : <String>[];
    final amountRaw = d['amount'];
    return PackageModel(
      id: doc.id,
      nameAr: d['nameAr'] as String?,
      nameEn: d['nameEn'] as String?,
      serviceIds: list,
      numberOfSessions: (d['numberOfSessions'] as num?)?.toInt() ?? 1,
      amount: amountRaw != null ? (amountRaw is num ? amountRaw.toDouble() : (double.tryParse(amountRaw.toString()) ?? 0)) : 0,
      isActive: d['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nameAr': nameAr,
      'nameEn': nameEn,
      'serviceIds': serviceIds,
      'numberOfSessions': numberOfSessions,
      'amount': amount,
      'isActive': isActive,
    };
  }
}
