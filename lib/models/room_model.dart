import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  final String id;
  final String? nameAr;
  final String? nameEn;
  final String? roomType;
  final bool isActive;

  const RoomModel({
    required this.id,
    this.nameAr,
    this.nameEn,
    this.roomType,
    this.isActive = true,
  });

  String get displayName => (nameAr?.isNotEmpty == true) ? nameAr! : (nameEn ?? id);

  factory RoomModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return RoomModel(
      id: doc.id,
      nameAr: d['nameAr'] as String?,
      nameEn: d['nameEn'] as String?,
      roomType: d['roomType'] as String?,
      isActive: d['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nameAr': nameAr,
      'nameEn': nameEn,
      'roomType': roomType,
      'isActive': isActive,
    };
  }
}
