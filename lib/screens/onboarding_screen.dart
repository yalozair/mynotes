import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardPage(
      icon: Icons.note_add,
      title: 'أنشئ مذكراتك بسهولة',
      body: 'محرر غني بالعربية، قوالب جاهزة، OCR، وتحويل الصوت إلى نص — كلها محلياً.',
    ),
    _OnboardPage(
      icon: Icons.cloud_sync,
      title: 'احفظ ومزامن',
      body: 'يُحفظ كل شيء على جهازك فوراً. سجّل الدخول للمزامنة السحابية المشفّرة عبر Firebase.',
    ),
    _OnboardPage(
      icon: Icons.security,
      title: 'أمان وخصوصية',
      body: 'قفل التطبيق بقفل جهازك، تشفير المذكرات، ونسخ احتياطي مشفّر — بدون اشتراكات.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: widget.onComplete, child: const Text('تخطي')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(p.icon, size: 100, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 32),
                        Text(p.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Text(p.body, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.5, color: Colors.grey.shade600)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _page ? Theme.of(context).colorScheme.primary : Colors.grey.shade400,
                ),
              )),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.all(24),
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
    );
  }
}

class _OnboardPage {
  final IconData icon;
  final String title;
  final String body;
  const _OnboardPage({required this.icon, required this.title, required this.body});
}
