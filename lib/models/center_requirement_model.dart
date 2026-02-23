import 'package:cloud_firestore/cloud_firestore.dart';

/// Item the center needs to buy (admin to-do / requirements list).
class CenterRequirementModel {
  final String id;
  final String title;
  final String? description;
  final String? quantity;
  final bool completed;
  final String? createdByUserId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CenterRequirementModel({
    required this.id,
    required this.title,
    this.description,
    this.quantity,
    this.completed = false,
    this.createdByUserId,
    this.createdAt,
    this.updatedAt,
  });

  factory CenterRequirementModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CenterRequirementModel(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String?,
      quantity: d['quantity'] as String?,
      completed: d['completed'] as bool? ?? false,
      createdByUserId: d['createdByUserId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'quantity': quantity,
      'completed': completed,
      'createdByUserId': createdByUserId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
