import 'package:cloud_firestore/cloud_firestore.dart';

class PatientProfileModel {
  final String id; // userId
  final String userId;
  final String? dateOfBirth;
  /// Age in years when patient does not share date of birth. Optional.
  final int? age;
  final String? gender;
  final String? address;
  final String? occupation;
  final String? referredBy;
  final String? maritalStatus;
  final String? areasToTreat;
  final String? feesType;
  final String? diagnosis;
  final String? followedByDoctorId;
  final String? medicalHistory;
  final String? treatmentProgress;
  final String? progressNotes;
  /// Physical therapy: chief complaint / reason for referral.
  final String? chiefComplaint;
  /// Pain level (e.g. VAS 0-10).
  final String? painLevel;
  /// Treatment goals.
  final String? treatmentGoals;
  /// Contraindications / precautions.
  final String? contraindications;
  /// Previous PT or surgery.
  final String? previousTreatment;
  final DateTime? updatedAt;

  const PatientProfileModel({
    required this.id,
    required this.userId,
    this.dateOfBirth,
    this.age,
    this.gender,
    this.address,
    this.occupation,
    this.referredBy,
    this.maritalStatus,
    this.areasToTreat,
    this.feesType,
    this.diagnosis,
    this.followedByDoctorId,
    this.medicalHistory,
    this.treatmentProgress,
    this.progressNotes,
    this.chiefComplaint,
    this.painLevel,
    this.treatmentGoals,
    this.contraindications,
    this.previousTreatment,
    this.updatedAt,
  });

  factory PatientProfileModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PatientProfileModel(
      id: doc.id,
      userId: d['userId'] as String? ?? doc.id,
      dateOfBirth: d['dateOfBirth'] as String?,
      age: (d['age'] as num?)?.toInt(),
      gender: d['gender'] as String?,
      address: d['address'] as String?,
      occupation: d['occupation'] as String?,
      referredBy: d['referredBy'] as String?,
      maritalStatus: d['maritalStatus'] as String?,
      areasToTreat: d['areasToTreat'] as String?,
      feesType: d['feesType'] as String?,
      diagnosis: d['diagnosis'] as String?,
      followedByDoctorId: d['followedByDoctorId'] as String?,
      medicalHistory: d['medicalHistory'] as String?,
      treatmentProgress: d['treatmentProgress'] as String?,
      progressNotes: d['progressNotes'] as String?,
      chiefComplaint: d['chiefComplaint'] as String?,
      painLevel: d['painLevel'] as String?,
      treatmentGoals: d['treatmentGoals'] as String?,
      contraindications: d['contraindications'] as String?,
      previousTreatment: d['previousTreatment'] as String?,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'dateOfBirth': dateOfBirth,
      'age': age,
      'gender': gender,
      'address': address,
      'occupation': occupation,
      'referredBy': referredBy,
      'maritalStatus': maritalStatus,
      'areasToTreat': areasToTreat,
      'feesType': feesType,
      'diagnosis': diagnosis,
      'followedByDoctorId': followedByDoctorId,
      'medicalHistory': medicalHistory,
      'treatmentProgress': treatmentProgress,
      'progressNotes': progressNotes,
      'chiefComplaint': chiefComplaint,
      'painLevel': painLevel,
      'treatmentGoals': treatmentGoals,
      'contraindications': contraindications,
      'previousTreatment': previousTreatment,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

enum DocumentType { ray, lab, report, image, pdf, note, other }

extension DocumentTypeExt on DocumentType {
  String get value => name;
  static DocumentType fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'ray': return DocumentType.ray;
      case 'lab': return DocumentType.lab;
      case 'report': return DocumentType.report;
      case 'image': return DocumentType.image;
      case 'pdf': return DocumentType.pdf;
      case 'note': return DocumentType.note;
      case 'other': return DocumentType.other;
      default: return DocumentType.other;
    }
  }
}

class PatientDocumentModel {
  final String id;
  final String patientId;
  final DocumentType documentType;
  final String filePathOrUrl;
  final String fileName;
  final String? mimeType;
  final String? descriptionAr;
  final String? descriptionEn;
  /// For type [note]: the text content. For image/PDF: optional description.
  final String? textContent;
  final String? uploadedByUserId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PatientDocumentModel({
    required this.id,
    required this.patientId,
    this.documentType = DocumentType.other,
    this.filePathOrUrl = '',
    this.fileName = '',
    this.mimeType,
    this.descriptionAr,
    this.descriptionEn,
    this.textContent,
    this.uploadedByUserId,
    this.createdAt,
    this.updatedAt,
  });

  factory PatientDocumentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PatientDocumentModel(
      id: doc.id,
      patientId: d['patientId'] as String? ?? '',
      documentType: DocumentTypeExt.fromString(d['documentType'] as String?),
      filePathOrUrl: d['filePathOrUrl'] as String? ?? '',
      fileName: d['fileName'] as String? ?? '',
      mimeType: d['mimeType'] as String?,
      descriptionAr: d['descriptionAr'] as String?,
      descriptionEn: d['descriptionEn'] as String?,
      textContent: d['textContent'] as String?,
      uploadedByUserId: d['uploadedByUserId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'documentType': documentType.value,
      'filePathOrUrl': filePathOrUrl,
      'fileName': fileName,
      'mimeType': mimeType,
      'descriptionAr': descriptionAr,
      'descriptionEn': descriptionEn,
      'textContent': textContent,
      'uploadedByUserId': uploadedByUserId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
