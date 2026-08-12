class Note {
  int? id;
  String title;
  String content;
  String? contentHtml;
  int fontSize;
  bool isBold;
  bool isUnderlined;
  String color;
  String fontName;
  bool isRtl;
  bool isCenter;
  bool isLtr;
  int timestamp;
  bool isDeleted;
  int deletedAt;
  int reminderTime;
  int reminderRepeat;
  String tags;
  String category;
  int cardColor;
  bool isEncrypted;
  String? userId;
  bool isSynced;

  Note({
    this.id,
    required this.title,
    required this.content,
    this.contentHtml,
    this.fontSize = 20,
    this.isBold = false,
    this.isUnderlined = false,
    this.color = 'Black',
    this.fontName = 'sans-serif',
    this.isRtl = true,
    this.isCenter = false,
    this.isLtr = false,
    required this.timestamp,
    this.isDeleted = false,
    this.deletedAt = 0,
    this.reminderTime = 0,
    this.reminderRepeat = 0,
    this.tags = '',
    this.category = 'عام',
    this.cardColor = 0,
    this.isEncrypted = false,
    this.userId,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'contentHtml': contentHtml,
      'fontSize': fontSize,
      'isBold': isBold ? 1 : 0,
      'isUnderlined': isUnderlined ? 1 : 0,
      'color': color,
      'fontName': fontName,
      'isRtl': isRtl ? 1 : 0,
      'isCenter': isCenter ? 1 : 0,
      'isLtr': isLtr ? 1 : 0,
      'timestamp': timestamp,
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt,
      'reminderTime': reminderTime,
      'reminderRepeat': reminderRepeat,
      'tags': tags,
      'category': category,
      'cardColor': cardColor,
      'isEncrypted': isEncrypted ? 1 : 0,
      'userId': userId,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: _toIntOrNull(map['id']),
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      contentHtml: map['contentHtml']?.toString(),
      fontSize: _toInt(map['fontSize'], 20),
      isBold: _toBool(map['isBold']),
      isUnderlined: _toBool(map['isUnderlined']),
      color: map['color']?.toString() ?? 'Black',
      fontName: map['fontName']?.toString() ?? 'sans-serif',
      isRtl: map['isRtl'] == null ? true : _toBool(map['isRtl']),
      isCenter: _toBool(map['isCenter']),
      isLtr: _toBool(map['isLtr']),
      timestamp: _toInt(map['timestamp']),
      isDeleted: _toBool(map['isDeleted']),
      deletedAt: _toInt(map['deletedAt']),
      reminderTime: _toInt(map['reminderTime']),
      reminderRepeat: _toInt(map['reminderRepeat']),
      tags: map['tags']?.toString() ?? '',
      category: map['category']?.toString() ?? 'عام',
      cardColor: _toInt(map['cardColor']),
      isEncrypted: _toBool(map['isEncrypted']),
      userId: map['userId']?.toString(),
      isSynced: _toBool(map['isSynced']),
    );
  }

  static int _toInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is bool) return value ? 1 : 0;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final text = value.toString().toLowerCase();
    return text == '1' || text == 'true';
  }
}
