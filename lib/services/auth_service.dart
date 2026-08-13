import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  bool get _isReady => Firebase.apps.isNotEmpty;

  User? get currentUser => _isReady ? _auth.currentUser : null;

  Stream<User?> get userStream => _isReady ? _auth.authStateChanges() : Stream.value(null);

  Future<UserCredential> signUp(String email, String password) async {
    if (!_isReady) throw Exception('Firebase غير مهيأ على هذا الجهاز');
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user?.sendEmailVerification();
    return cred;
  }

  Future<UserCredential> signIn(String email, String password) async {
    if (!_isReady) throw Exception('Firebase غير مهيأ على هذا الجهاز');
    final cred = await _signInRaw(email, password);
    await cred.user?.reload();
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'يرجى تأكيد بريدك الإلكتروني قبل تسجيل الدخول',
      );
    }
    return cred;
  }

  Future<UserCredential> _signInRaw(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> resendVerificationEmail(String email, String password) async {
    if (!_isReady) throw Exception('Firebase غير مهيأ');
    final cred = await _signInRaw(email, password);
    await cred.user?.sendEmailVerification();
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    if (!_isReady) throw Exception('Firebase غير مهيأ على هذا الجهاز');
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    if (_isReady) await _auth.signOut();
  }

  /// يحذف مستندات المستخدم في Firestore ثم حساب Firebase Auth.
  /// قد يتطلب إعادة مصادقة حديثة من النظام.
  Future<void> deleteAccountAndCloudData() async {
    if (!_isReady) throw Exception('Firebase غير مهيأ على هذا الجهاز');
    final user = _auth.currentUser;
    if (user == null) throw Exception('لا يوجد حساب مسجّل');

    final uid = user.uid;
    final db = FirebaseFirestore.instance;

    Future<void> deleteQuery(Query<Map<String, dynamic>> q) async {
      final snap = await q.limit(200).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
      if (snap.docs.length >= 200) {
        await deleteQuery(q);
      }
    }

    try {
      await deleteQuery(db.collection('notes').where('userId', isEqualTo: uid));
    } catch (e) {
      debugPrint('delete notes: $e');
    }
    try {
      await deleteQuery(db.collection('shared_notes').where('ownerId', isEqualTo: uid));
    } catch (e) {
      debugPrint('delete shares: $e');
    }

    await user.delete();
  }
}
