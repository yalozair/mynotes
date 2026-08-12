import 'package:flutter_test/flutter_test.dart';
import 'package:my_nots_flutter/helpers/encryption_helper.dart';
import 'package:my_nots_flutter/models/note.dart';
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
    });

    expect(note.id, 12);
    expect(note.title, 'عنوان');
    expect(note.isDeleted, isTrue);
    expect(note.isEncrypted, isFalse);
    expect(note.isSynced, isTrue);
    expect(note.category, 'عام');
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
}
