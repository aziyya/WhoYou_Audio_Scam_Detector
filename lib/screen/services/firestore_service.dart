import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final CollectionReference reports = FirebaseFirestore.instance.collection(
    'reports',
  );

  Future<void> submitReport({
    required String phoneNumber,
    String? description,
    required String userId,
  }) async {
    await reports.add({
      'phone_number': phoneNumber,
      'description': description ?? '',
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
