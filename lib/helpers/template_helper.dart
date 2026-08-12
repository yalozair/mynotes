import 'dart:convert';
import '../models/note.dart';

class NoteTemplate {
  final String id;
  final String title;
  final String category;
  final String icon;
  final String contentPlain;

  const NoteTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.contentPlain,
  });

  String get contentHtml {
    final doc = [
      {'insert': '$contentPlain\n'},
    ];
    return jsonEncode(doc);
  }

  Note toNote() {
    return Note(
      title: title,
      content: contentPlain.trim(),
      contentHtml: contentHtml,
      category: category,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class TemplateHelper {
  static const templates = <NoteTemplate>[
    NoteTemplate(
      id: 'meeting',
      title: 'محضر اجتماع',
      category: 'عام',
      icon: 'groups',
      contentPlain: '''📅 التاريخ: 
👥 الحضور: 
📋 جدول الأعمال:
1. 
2. 

✅ القرارات:
- 

📝 مهام المتابعة:
- [ ] 
''',
    ),
    NoteTemplate(
      id: 'tasks',
      title: 'قائمة مهام',
      category: 'شخصي',
      icon: 'checklist',
      contentPlain: '''🎯 الأولوية العالية:
- [ ] 

📌 اليوم:
- [ ] 

💡 لاحقاً:
- [ ] 
''',
    ),
    NoteTemplate(
      id: 'shopping',
      title: 'قائمة تسوق',
      category: 'عام',
      icon: 'shopping_cart',
      contentPlain: '''🛒 قائمة التسوق

🥬 خضروات:
- [ ] 

🥩 لحوم:
- [ ] 

🏠 منزل:
- [ ] 

💰 الميزانية: 
''',
    ),
    NoteTemplate(
      id: 'journal',
      title: 'يوميات',
      category: 'خاص',
      icon: 'book',
      contentPlain: '''📖 يوميات — 

😊 مزاج اليوم: 
⭐ أبرز لحظة: 
💭 أفكار: 

🙏 امتنان:
1. 
2. 
3. 
''',
    ),
    NoteTemplate(
      id: 'study',
      title: 'ملاحظات دراسية',
      category: 'عام',
      icon: 'school',
      contentPlain: '''📚 المادة: 
📌 الموضوع: 

🔑 النقاط الرئيسية:
• 
• 

❓ أسئلة للمراجعة:
1. 

📎 مراجع: 
''',
    ),
  ];

  static NoteTemplate? byId(String id) {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }
}
