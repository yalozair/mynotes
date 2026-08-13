import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// سياسة خصوصية داخل التطبيق + رابط خارجي اختياري (مطلوب لـ Play / AdMob).
class PrivacyHelper {
  /// حدّث هذا الرابط عند نشر صفحة خصوصية عامة على الاستضافة.
  static const publicPolicyUrl =
      'https://mysmartnotes-8459e.web.app/privacy';

  static const policyTitle = 'سياسة الخصوصية — مفكرتي';

  static const policyBody = '''
آخر تحديث: أغسطس 2026

تطبيق «مفكرتي» (com.alozair.my_nots) يحترم خصوصيتك. توضح هذه السياسة البيانات التي نجمعها وكيف نستخدمها.

1) البيانات التي تخزَّن على جهازك
• المذكرات والمجلدات والوسوم والنسخ السابقة تُحفظ محلياً في قاعدة بيانات على جهازك.
• إعدادات المظهر والقفل والورق تُحفظ في تفضيلات الجهاز.
• مفتاح التشفير المحلي يُنشأ عشوائياً على الجهاز ولا يُرسل كما هو إلى خوادمنا.

2) الحساب والمزامنة السحابية (اختياري)
• عند تسجيل الدخول عبر Firebase Authentication نستخدم بريدك الإلكتروني لإدارة الحساب.
• عند تفعيل المزامنة تُرفع المذكرات إلى Cloud Firestore مشفّرة بمفتاح مرتبط بحسابك.
• يمكنك تسجيل الخروج في أي وقت. حذف الحساب متاح من الإعدادات ويحاول إزالة بيانات السحابة المرتبطة بحسابك.

3) النسخ الاحتياطي
• التصدير المحلي ينشئ ملفًا مشفّرًا (.mynotes) مرتبطًا بمفتاح هذا الجهاز؛ قد لا يُفتح على جهاز آخر بدون نفس المفتاح/الجهاز.
• النسخ إلى Google Drive يتم فقط بعد موافقتك عبر تسجيل Google، ويستخدم صلاحية drive.file (ملفات أنشأها التطبيق فقط).

4) الأذونات (تُطلب عند الحاجة)
• الإشعارات: للتذكيرات واختصار المذكرة السريعة.
• الكاميرا / الصور: لـ OCR وإرفاق الصور فقط عند اختيارك ذلك.
• الميكروفون: لتحويل الصوت إلى نص عند تفعيله.
• الظهور فوق التطبيقات: فقط عند تفعيل المذكرة العائمة.
• المنبّه الدقيق: لتذكيرات في الوقت المحدد.

5) الإعلانات والقياس
• نعرض إعلانات عبر Google AdMob (إعلان فتح وإعلان بيني محدود).
• في المناطق التي تتطلب موافقة (مثل المنطقة الاقتصادية الأوروبية والمملكة المتحدة) نستخدم Google User Messaging Platform (UMP) لجمع الموافقة قبل طلب الإعلانات المخصصة.
• قد تجمع Google معرّفات إعلانية وبيانات استخدام لأغراض الإعلان والقياس وفق سياسة Google.

6) التحليلات والأعطال
• قد نستخدم Firebase Analytics / Crashlytics لفهم الاستقرار وتحسين التطبيق (أحداث مجمّعة، بدون قراءة محتوى مذكراتك كنص صريح في أدوات التحليل الخاصة بنا).

7) المشاركة
• «رابط مشاركة مؤقت» يرفع عنوان المذكرة ومحتواها النصّي غير المشفّر إلى Firestore لفترة محدودة (حوالي 7 أيام). لا تستخدمه للمذكرات الحساسة أو المشفّرة.
• التطبيق يرفض مشاركة المذكرات المشفّرة برابط.

8) حقوقك
• الوصول والتصدير: من الإعدادات (نسخ احتياطي / تصدير).
• الحذف: سلة المحذوفات، وحذف الحساب من الإعدادات.
• خيارات خصوصية الإعلانات: من الإعدادات عند توفرها في منطقتك.

9) الأطفال
• التطبيق غير موجّه للأطفال دون 13 عامًا، ولا نجمع عن قصد بيانات منهم.

10) التواصل
• للاستفسارات حول الخصوصية تواصل مع مطوّر التطبيق عبر صفحة المتجر أو البريد المذكور في قائمة Play.

باستخدامك للتطبيق فإنك تقرّ باطلاعك على هذه السياسة. قد نحدّث النص؛ سيظهر تاريخ التحديث أعلاه.
''';

  static Future<void> openPublicPolicy() async {
    final uri = Uri.parse(publicPolicyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> showPrivacyScreen(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PrivacyPolicyScreen(),
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(PrivacyHelper.policyTitle),
        actions: [
          IconButton(
            tooltip: 'فتح النسخة على الويب',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              try {
                await PrivacyHelper.openPublicPolicy();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تعذر فتح الرابط — يمكنك قراءة السياسة هنا'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: SelectableText(
          PrivacyHelper.policyBody,
          style: TextStyle(height: 1.55, fontSize: 14.5),
        ),
      ),
    );
  }
}
