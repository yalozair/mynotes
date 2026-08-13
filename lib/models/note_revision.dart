class NoteRevision {
  final int? id;
  final int noteId;
  final String title;
  final String content;
  final String? contentHtml;
  final int savedAt;

  const NoteRevision({
    this.id,
    required this.noteId,
    required this.title,
    required this.content,
    this.contentHtml,
    required this.savedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'noteId': noteId,
        'title': title,
        'content': content,
        'contentHtml': contentHtml,
        'savedAt': savedAt,
      };

  factory NoteRevision.fromMap(Map<String, dynamic> map) => NoteRevision(
        id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
        noteId: map['noteId'] is int ? map['noteId'] as int : int.tryParse('${map['noteId']}') ?? 0,
        title: map['title']?.toString() ?? '',
        content: map['content']?.toString() ?? '',
        contentHtml: map['contentHtml']?.toString(),
        savedAt: map['savedAt'] is int ? map['savedAt'] as int : int.tryParse('${map['savedAt']}') ?? 0,
      );
}
