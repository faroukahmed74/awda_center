import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceModel {
  final String id;
  final String? nameAr;
  final String? nameEn;
  /// Optional description (shown in services list and Price Quote).
  final String? description;
  /// Price/amount for this service (used for session amount calculation).
  final double? amount;
  final bool isActive;

  const ServiceModel({
    required this.id,
    this.nameAr,
    this.nameEn,
    this.description,
    this.amount,
    this.isActive = true,
  });

  String get displayName => (nameAr?.isNotEmpty == true) ? nameAr! : (nameEn ?? id);

  /// Sum of amounts for the given service ids (for session/appointment total calculation).
  static double totalAmountForIds(List<String> ids, List<ServiceModel> services) {
    double sum = 0;
    for (final id in ids) {
      for (final s in services) {
        if (s.id == id && s.amount != null) {
          sum += s.amount!;
          break;
        }
      }
    }
    return sum;
  }

  factory ServiceModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final amountRaw = d['amount'];
    return ServiceModel(
      id: doc.id,
      nameAr: d['nameAr'] as String?,
      nameEn: d['nameEn'] as String?,
      description: d['description'] as String?,
      amount: amountRaw != null ? (amountRaw is num ? amountRaw.toDouble() : double.tryParse(amountRaw.toString())) : null,
      isActive: d['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nameAr': nameAr,
      'nameEn': nameEn,
      'description': description,
      'amount': amount,
      'isActive': isActive,
    };
  }

  ServiceModel copyWith({
    String? id,
    String? nameAr,
    String? nameEn,
    String? description,
    double? amount,
    bool? isActive,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      isActive: isActive ?? this.isActive,
    );
  }
}
