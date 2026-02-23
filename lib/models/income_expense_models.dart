import 'package:cloud_firestore/cloud_firestore.dart';

class IncomeRecordModel {
  final String id;
  final double amount;
  final String currency;
  final String source;
  final String? doctorId;
  final String? patientId;
  final String? notes;
  final String? recordedByUserId;
  final DateTime incomeDate;
  final DateTime? createdAt;

  const IncomeRecordModel({
    required this.id,
    required this.amount,
    this.currency = 'EGP',
    required this.source,
    this.doctorId,
    this.patientId,
    this.notes,
    this.recordedByUserId,
    required this.incomeDate,
    this.createdAt,
  });

  factory IncomeRecordModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    Timestamp? dateTs = d['incomeDate'] as Timestamp?;
    return IncomeRecordModel(
      id: doc.id,
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      currency: d['currency'] as String? ?? 'EGP',
      source: d['source'] as String? ?? '',
      doctorId: d['doctorId'] as String?,
      patientId: d['patientId'] as String?,
      notes: d['notes'] as String?,
      recordedByUserId: d['recordedByUserId'] as String?,
      incomeDate: dateTs?.toDate() ?? DateTime.now(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'currency': currency,
      'source': source,
      'doctorId': doctorId,
      'patientId': patientId,
      'notes': notes,
      'recordedByUserId': recordedByUserId,
      'incomeDate': Timestamp.fromDate(incomeDate),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}

class ExpenseRecordModel {
  final String id;
  final double amount;
  final String category;
  final String? description;
  final String? recordedByUserId;
  final DateTime expenseDate;
  final DateTime? createdAt;

  const ExpenseRecordModel({
    required this.id,
    required this.amount,
    required this.category,
    this.description,
    this.recordedByUserId,
    required this.expenseDate,
    this.createdAt,
  });

  factory ExpenseRecordModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    Timestamp? dateTs = d['expenseDate'] as Timestamp?;
    return ExpenseRecordModel(
      id: doc.id,
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      category: d['category'] as String? ?? '',
      description: d['description'] as String?,
      recordedByUserId: d['recordedByUserId'] as String?,
      expenseDate: dateTs?.toDate() ?? DateTime.now(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'category': category,
      'description': description,
      'recordedByUserId': recordedByUserId,
      'expenseDate': Timestamp.fromDate(expenseDate),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
