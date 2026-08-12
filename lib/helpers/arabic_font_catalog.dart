import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ArabicFontOption {
  final String id;
  final String labelAr;
  final String category;
  final String sample;

  const ArabicFontOption({
    required this.id,
    required this.labelAr,
    required this.category,
    required this.sample,
  });
}

class ArabicFontCatalog {
  static const samplePhrase = 'بسم الله الرحمن الرحيم — مفكرتي';

  static const fonts = <ArabicFontOption>[
    ArabicFontOption(id: 'Cairo', labelAr: 'القاهرة', category: 'عصري', sample: 'خط عصري واضح للمذكرات اليومية'),
    ArabicFontOption(id: 'Noto Naskh Arabic', labelAr: 'نسخ — نوتو', category: 'نسخ', sample: 'خط النسخ التقليدي الأنيق'),
    ArabicFontOption(id: 'Amiri', labelAr: 'نسخ — أمiri', category: 'نسخ', sample: 'خط أمiri الكلاسيكي للقراءة'),
    ArabicFontOption(id: 'Scheherazade New', labelAr: 'نسخ — شهرزاد', category: 'نسخ', sample: 'خط نسخ تراثي مريح للعين'),
    ArabicFontOption(id: 'Katibeh', labelAr: 'ديواني — كاتبة', category: 'ديواني', sample: 'خط كتابي قريب من الديواني'),
    ArabicFontOption(id: 'Aref Ruqaa Ink', labelAr: 'رقعة — حبر', category: 'رقعة', sample: 'خط الرقعة بملمس الحبر'),
    ArabicFontOption(id: 'Aref Ruqaa', labelAr: 'رقعة', category: 'رقعة', sample: 'خط الرقعة العربي الجميل'),
    ArabicFontOption(id: 'Reem Kufi', labelAr: 'كوفي — ريم', category: 'كوفي', sample: 'خط كوفي عصري مميز'),
    ArabicFontOption(id: 'Noto Kufi Arabic', labelAr: 'كوفي — نوتو', category: 'كوفي', sample: 'خط كوفي متوازن للعناوين'),
    ArabicFontOption(id: 'Lateef', labelAr: 'لطيف', category: 'زخرفي', sample: 'خط لطيف أنيق للتدوينات'),
    ArabicFontOption(id: 'El Messiri', labelAr: 'المسيري', category: 'زخرفي', sample: 'خط عربي أنيق للعناوين'),
    ArabicFontOption(id: 'Harmattan', labelAr: 'هرمattan', category: 'زخرفي', sample: 'خط مميز للنصوص الأدبية'),
    ArabicFontOption(id: 'Markazi Text', labelAr: 'مركزي', category: 'عناوين', sample: 'خط عناوين عربي بارز'),
    ArabicFontOption(id: 'Tajawal', labelAr: 'تجول', category: 'عصري', sample: 'خط حديث نظيف'),
    ArabicFontOption(id: 'Almarai', labelAr: 'المرai', category: 'عصري', sample: 'خط بسيط وواضح'),
    ArabicFontOption(id: 'IBM Plex Sans Arabic', labelAr: 'IBM Plex', category: 'عصري', sample: 'خط احترافي للمحتوى الطويل'),
  ];

  static TextStyle previewStyle(String fontId, {double size = 22}) {
    return GoogleFonts.getFont(fontId, fontSize: size);
  }

  static void showPicker({
    required BuildContext context,
    required String selectedFontId,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'اختر الخط',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: fonts.length,
                itemBuilder: (context, i) {
                  final font = fonts[i];
                  final selected = selectedFontId == font.id;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    color: selected
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
                        : Theme.of(context).cardColor,
                    child: ListTile(
                      title: Row(
                        children: [
                          Text(font.labelAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(font.category, style: const TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          font.sample,
                          style: previewStyle(font.id),
                        ),
                      ),
                      trailing: selected ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor) : null,
                      onTap: () {
                        onSelected(font.id);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
