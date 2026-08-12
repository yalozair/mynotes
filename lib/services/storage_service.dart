import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _user => _auth.currentUser;

  Future<String?> uploadNoteImage(String localPath) async {
    if (_user == null) return null;

    final file = File(localPath);
    if (!file.existsSync()) return null;

    try {
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.png';
      
      // Use .child() only. Firebase Storage References do NOT have a .doc() method.
      final ref = _storage
          .ref()
          .child('users')
          .child(_user!.uid)
          .child('note_images')
          .child(fileName);

      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Firebase Storage Upload Error: $e");
      return null;
    }
  }
}
