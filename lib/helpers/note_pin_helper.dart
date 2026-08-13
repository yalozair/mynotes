import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

/// PIN للمذكرات المشفّرة (تجزئة فقط — لا نخزّن الرقم السري).
class NotePinHelper {
  static String hashPin(String pin) {
    final digest = sha256.convert(utf8.encode('mofkarti_pin_v1|$pin'));
    return digest.toString();
  }

  static bool verify(String pin, String? storedHash) {
    if (storedHash == null || storedHash.isEmpty) return true;
    return hashPin(pin) == storedHash;
  }

  static Future<String?> askNewPin(BuildContext context) async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('رمز PIN للتشفير'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'لحماية المذكرة يلزم رمز PIN (4 أرقام على الأقل). '
              'يُحفظ كتجزئة فقط على الجهاز، ولن نتمكن من استعادته إن نسيته.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'تأكيد PIN',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final a = pinCtrl.text.trim();
              final b = confirmCtrl.text.trim();
              if (a.length < 4) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('الرمز يجب أن يكون 4 أحرف/أرقام على الأقل')),
                );
                return;
              }
              if (a != b) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('الرمزان غير متطابقين')),
                );
                return;
              }
              Navigator.pop(ctx, a);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    pinCtrl.dispose();
    confirmCtrl.dispose();
    return result;
  }

  static Future<bool> askVerifyPin(
    BuildContext context, {
    required String? storedHash,
    String title = 'أدخل PIN المذكرة',
  }) async {
    if (storedHash == null || storedHash.isEmpty) return true;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'PIN',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            if (verify(ctrl.text.trim(), storedHash)) {
              Navigator.pop(ctx, true);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (verify(ctrl.text.trim(), storedHash)) {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('رمز غير صحيح')),
                );
              }
            },
            child: const Text('فتح'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return ok == true;
  }
}
