import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

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
}
