import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:my_nots_flutter/services/auth_service.dart';
import 'package:my_nots_flutter/providers/note_provider.dart';
import 'package:my_nots_flutter/helpers/permission_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isSignUp = false;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _snack('يرجى ملء كافة الحقول');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        await _authService.signUp(email, password);
        if (!mounted) return;
        await _authService.signOut();
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تحقق من بريدك'),
            content: const Text(
              'تم إرسال رابط تحقق إلى بريدك الإلكتروني.\n'
              'افتح الرابط ثم سجّل الدخول.\n\n'
              'ملاحظة: التحقق برمز OTP يتطلب إعداد Firebase Functions. '
              'حالياً نستخدم رابط التحقق الرسمي من Firebase.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
            ],
          ),
        );
        setState(() => _isSignUp = false);
      } else {
        final cred = await _authService.signIn(email, password);
        if (!mounted) return;
        await PermissionHelper.ensureNotifications(context);
        if (!mounted) return;
        Provider.of<NoteProvider>(context, listen: false).bindUser(cred.user?.uid);
        await Provider.of<NoteProvider>(context, listen: false).syncAll();
        if (mounted) Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      _snack(_mapAuthError(e));
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _snack('أدخل بريدك الإلكتروني أولاً');
      return;
    }
    try {
      await _authService.sendPasswordReset(email);
      _snack('تم إرسال رابط استعادة كلمة المرور إلى بريدك', success: true);
    } catch (e) {
      _snack('تعذر إرسال رابط الاستعادة');
    }
  }

  Future<void> _resendVerification() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _snack('أدخل البريد وكلمة المرور لإعادة إرسال التحقق');
      return;
    }
    try {
      await _authService.resendVerificationEmail(email, password);
      _snack('تم إرسال رابط التحقق مرة أخرى', success: true);
    } catch (_) {
      _snack('تعذر إرسال رابط التحقق');
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-not-verified':
        return 'يرجى تأكيد بريدك الإلكتروني قبل تسجيل الدخول';
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'هذا البريد مستخدم بالفعل';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'network-request-failed':
        return 'تحقق من اتصال الإنترنت';
      default:
        return e.message ?? e.code;
    }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.redAccent,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUp ? 'إنشاء حساب جديد' : 'تسجيل الدخول للمزامنة'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.cloud_sync, size: 90, color: Colors.blueAccent),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                obscureText: true,
              ),
              if (!_isSignUp)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _isLoading ? null : _forgotPassword,
                    child: const Text('نسيت كلمة المرور؟'),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isSignUp ? 'اشتراك وإرسال تحقق' : 'دخول'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp ? 'لديك حساب؟ سجل دخولك' : 'ليس لديك حساب؟ أنشئ حساباً',
                  style: TextStyle(color: isDark ? Colors.cyanAccent : null),
                ),
              ),
              if (!_isSignUp)
                TextButton(
                  onPressed: _isLoading ? null : _resendVerification,
                  child: const Text('إعادة إرسال رابط التحقق'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
