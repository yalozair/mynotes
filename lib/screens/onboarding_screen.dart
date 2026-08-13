import 'package:flutter/material.dart';
import '../helpers/privacy_helper.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _acceptedPrivacy = false;

  static const _pages = [
    _OnboardPage(
      icon: Icons.menu_book_rounded,
      title: 'مفكرتي',
      body:
          'دفترك الورقي الرقمي: محرر عربي، أسطر وملمس ورق، قوالب، OCR، وإملاء صوتي — على جهازك أولاً.',
      brand: true,
    ),
    _OnboardPage(
      icon: Icons.flash_on_rounded,
      title: 'مذكرة سريعة دائماً',
      body:
          'اختصار إشعار، بلاطة إعدادات سريعة، ومذكرة عائمة — اكتب فكرتك في ثوانٍ دون فتح التطبيق كاملاً.',
    ),
    _OnboardPage(
      icon: Icons.security,
      title: 'خصوصية أوضح',
      body:
          'قفل بجهازك، تشفير بـ PIN، ونسخ احتياطي مشفّر. الإعلانات تظهر بعد موافقة المنطقة عند الحاجة، والصلاحيات تُطلب وقت الاستخدام فقط.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }
    if (!_acceptedPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى الموافقة على سياسة الخصوصية للمتابعة')),
      );
      return;
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primary.withValues(alpha: 0.12),
              scheme.surface,
              scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    if (_acceptedPrivacy) {
                      widget.onComplete();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('وافق على سياسة الخصوصية من الصفحة الأخيرة أو أكمل الخطوات'),
                        ),
                      );
                      _pageController.animateToPage(
                        _pages.length - 1,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: const Text('تخطي'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    final p = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (p.brand)
                            Text(
                              'مفكرتي',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          if (p.brand) const SizedBox(height: 12),
                          Icon(p.icon, size: p.brand ? 72 : 96, color: scheme.primary),
                          const SizedBox(height: 28),
                          Text(
                            p.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: p.brand ? 22 : 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            p.body,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.55,
                              color: scheme.onSurface.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_page == _pages.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        value: _acceptedPrivacy,
                        onChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('أوافق على سياسة الخصوصية', style: TextStyle(fontSize: 14)),
                        subtitle: TextButton(
                          onPressed: () => PrivacyHelper.showPrivacyScreen(context),
                          child: const Text('قراءة السياسة'),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page ? scheme.primary : Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    child: Text(_page == _pages.length - 1 ? 'ابدأ الآن' : 'التالي'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage {
  final IconData icon;
  final String title;
  final String body;
  final bool brand;
  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.body,
    this.brand = false,
  });
}
