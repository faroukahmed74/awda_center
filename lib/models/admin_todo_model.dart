import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin to-do item with optional due date and reminder.
class AdminTodoModel {
  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final DateTime? reminderAt;
  final bool completed;
  final String? createdByUserId;
  final String? assignedToUserId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminTodoModel({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.reminderAt,
    this.completed = false,
    this.createdByUserId,
    this.assignedToUserId,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminTodoModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AdminTodoModel(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String?,
      dueDate: (d['dueDate'] as Timestamp?)?.toDate(),
      reminderAt: (d['reminderAt'] as Timestamp?)?.toDate(),
      completed: d['completed'] as bool? ?? false,
      createdByUserId: d['createdByUserId'] as String?,
      assignedToUserId: d['assignedToUserId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'reminderAt': reminderAt != null ? Timestamp.fromDate(reminderAt!) : null,
      'completed': completed,
      'createdByUserId': createdByUserId,
      'assignedToUserId': assignedToUserId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
