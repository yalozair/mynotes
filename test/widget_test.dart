import 'package:flutter_test/flutter_test.dart';
import 'package:my_nots_flutter/helpers/encryption_helper.dart';
import 'package:my_nots_flutter/helpers/writing_streak_helper.dart';
import 'package:my_nots_flutter/models/note.dart';
import 'package:my_nots_flutter/models/note_revision.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Note.fromMap handles Firestore-style and missing fields', () {
    final note = Note.fromMap({
      'id': '12',
      'title': 'عنوان',
      'content': 'محتوى',
      'timestamp': 1710000000000,
      'isDeleted': true,
      'isEncrypted': 0,
      'isSynced': '1',
      'isPinned': 1,
      'folder': 'عمل',
    });

    expect(note.id, 12);
    expect(note.title, 'عنوان');
    expect(note.isDeleted, isTrue);
    expect(note.isEncrypted, isFalse);
    expect(note.isSynced, isTrue);
    expect(note.isPinned, isTrue);
    expect(note.folder, 'عمل');
    expect(note.category, 'عام');
  });

  test('Note.toMap round-trips pin and folder fields', () {
    final note = Note(
      id: 3,
      title: 'مثبتة',
      content: 'نص',
      timestamp: 100,
      isPinned: true,
      folder: 'شخصي',
      folderColor: 0xFFFF0000,
      folderIcon: 'star',
    );
    final mapped = Note.fromMap(note.toMap());
    expect(mapped.isPinned, isTrue);
    expect(mapped.folder, 'شخصي');
    expect(mapped.folderColor, 0xFFFF0000);
    expect(mapped.folderIcon, 'star');
  });

  test('EncryptionHelper uses random IV and can decrypt its own output', () async {
    await EncryptionHelper.init();
    const plain = 'ملاحظة سرية';
    final first = EncryptionHelper.encryptText(plain);
    final second = EncryptionHelper.encryptText(plain);

    expect(first.startsWith('v2:'), isTrue);
    expect(first, isNot(equals(second)));
    expect(EncryptionHelper.decryptText(first), plain);
    expect(EncryptionHelper.decryptText(second), plain);
  });

  test('EncryptionHelper rejects empty ciphertext gracefully', () async {
    await EncryptionHelper.init();
    expect(EncryptionHelper.decryptText(''), '');
  });

  test('pinned notes sort ahead of newer unpinned notes', () {
    final pinnedOld = Note(
      id: 1,
      title: 'قديمة مثبتة',
      content: 'a',
      timestamp: 100,
      isPinned: true,
    );
    final fresh = Note(
      id: 2,
      title: 'جديدة',
      content: 'b',
      timestamp: 999,
      isPinned: false,
    );
    final list = [fresh, pinnedOld];
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.timestamp.compareTo(a.timestamp);
    });
    expect(list.first.id, 1);
    expect(list.last.id, 2);
  });

  test('unsynced flag models offline sync queue', () {
    final local = Note(
      id: 9,
      title: 'أوفلاين',
      content: 'محلي',
      timestamp: 1,
      isSynced: false,
    );
    final cloudReady = Note.fromMap({
      ...local.toMap(),
      'isSynced': 1,
    });
    expect(local.isSynced, isFalse);
    expect(cloudReady.isSynced, isTrue);
  });

  test('NoteRevision preserves contentHtml for restore', () {
    final rev = NoteRevision(
      noteId: 5,
      title: 'عنوان قديم',
      content: 'نص قديم',
      contentHtml: '[{"insert":"نص قديم\\n"}]',
      savedAt: 123456,
    );
    final mapped = NoteRevision.fromMap(rev.toMap());
    expect(mapped.noteId, 5);
    expect(mapped.contentHtml, contains('insert'));
    expect(mapped.savedAt, 123456);
  });

  test('WritingStreakHelper counts consecutive days', () async {
    final today = DateTime.now();
    String key(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'writing_days_v1': [
        key(today.subtract(const Duration(days: 2))),
        key(today.subtract(const Duration(days: 1))),
        key(today),
      ],
    });

    expect(await WritingStreakHelper.currentStreak(), 3);
    expect(await WritingStreakHelper.bestStreak(), 3);

    await WritingStreakHelper.markToday();
    expect(await WritingStreakHelper.currentStreak(), 3);
  });
}
