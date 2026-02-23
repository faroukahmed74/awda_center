import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Uploads patient documents (images/PDFs) to Firebase Storage.
/// Path: patient_docs/{patientId}/{timestamp}_{filename}
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Pick a file (image or PDF) and upload to Storage; returns download URL and chosen filename.
  /// Returns null if user cancels, or file could not be read (e.g. use a smaller file or paste URL).
  Future<({String url, String fileName})?> pickAndUploadForPatient(String patientId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;

    final name = file.name;
    final mimeType = (file.extension ?? '').toLowerCase() == 'pdf'
        ? 'application/pdf'
        : 'image/${file.extension ?? 'jpeg'}';

    final path = 'patient_docs/$patientId/${DateTime.now().millisecondsSinceEpoch}_$name';
    final ref = _storage.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: mimeType));
    final url = await ref.getDownloadURL();
    return (url: url, fileName: name);
  }
}
