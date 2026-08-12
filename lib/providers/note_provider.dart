import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/db_helper.dart';
import '../models/note.dart';
import '../helpers/native_helper.dart';
import '../helpers/encryption_helper.dart';

import '../helpers/tag_helper.dart';
import '../helpers/reminder_helper.dart';
import '../helpers/analytics_helper.dart';

enum SyncStatus { saved, syncing, pending, offline, error }

class NoteProvider with ChangeNotifier {
  List<Note> _notes = [];
  List<Note> _trashNotes = [];
  bool _isSyncing = false;
  String? lastError;
  final DBHelper _dbHelper = DBHelper();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  bool get isSyncing => _isSyncing;
  bool get isLoggedIn => _user != null;
  int get pendingSyncCount => _notes.where((n) => !n.isSynced).length;

  SyncStatus get syncStatus {
    if (_isSyncing) return SyncStatus.syncing;
    if (!_isFirebaseReady || _user == null) return SyncStatus.offline;
    if (lastError != null) return SyncStatus.error;
    if (pendingSyncCount > 0) return SyncStatus.pending;
    return SyncStatus.saved;
  }

  String get syncStatusLabel {
    switch (syncStatus) {
      case SyncStatus.syncing:
        return 'جاري المزامنة…';
      case SyncStatus.pending:
        return 'بانتظار المزامنة ($pendingSyncCount)';
      case SyncStatus.error:
        return lastError ?? 'خطأ في المزامنة';
      case SyncStatus.offline:
        return 'محفوظ محلياً';
      case SyncStatus.saved:
        return 'تم الحفظ والمزامنة';
    }
  }

  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  List<Note> get notes => _notes;
  List<Note> get trashNotes => _trashNotes;

  User? get _user => _isFirebaseReady ? _auth.currentUser : null;

  void bindUser(String? uid) {
    EncryptionHelper.setActiveUser(uid);
  }

  String _plainContentFor(Note note) {
    if (note.content != '••••••••' && note.content.isNotEmpty) return note.content;
    final html = EncryptionHelper.plainHtml(note.contentHtml);
    if (html.isEmpty) return note.content;
    try {
      return html.length > 200 ? '${html.substring(0, 200)}…' : html;
    } catch (_) {
      return note.content;
    }
  }

  String _plainHtmlFor(Note note) {
    if (note.contentHtml == null || note.contentHtml!.isEmpty) return '';
    return EncryptionHelper.plainHtml(note.contentHtml);
  }

  List<Note> notesFor({String query = '', String category = 'الكل', String tag = ''}) {
    final q = query.trim().toLowerCase();
    final tagQ = tag.trim().toLowerCase();
    return _notes.where((n) {
      final preview = _plainContentFor(n);
      final tagList = TagHelper.parseTags(n.tags).map((t) => t.toLowerCase()).toList();
      final matchesQuery = q.isEmpty ||
          n.title.toLowerCase().contains(q) ||
          preview.toLowerCase().contains(q) ||
          n.tags.toLowerCase().contains(q);
      final matchesTag = tagQ.isEmpty || tagList.contains(tagQ);
      final matchesCat = category == 'الكل' || n.category == category;
      return matchesQuery && matchesCat && matchesTag;
    }).toList();
  }

  List<String> get allTags {
    final tags = <String>{};
    for (final n in _notes) {
      tags.addAll(TagHelper.parseTags(n.tags));
    }
    return tags.toList()..sort();
  }

  String displayContent(Note note) {
    if (!note.isEncrypted) return note.content;
    if (note.content != '••••••••') return note.content;
    return 'ملاحظة مشفرة';
  }

  Future<void> fetchNotes() async {
    List<Note> fetched = await _dbHelper.getNotes(deleted: false);
    if (_user != null) {
      fetched = fetched.where((n) => n.userId == _user!.uid || n.userId == null).toList();
    }
    _notes = fetched;
    notifyListeners();
  }

  Future<void> fetchTrashNotes() async {
    _trashNotes = await _dbHelper.getNotes(deleted: true);
    if (_user != null) {
      _trashNotes = _trashNotes.where((n) => n.userId == _user!.uid || n.userId == null).toList();
    }
    notifyListeners();
  }

  Future<Note> addNote(Note note, {bool autoTag = true}) async {
    if (autoTag && note.tags.isEmpty && !note.isEncrypted) {
      note.tags = TagHelper.generateTags(note.title, note.content);
    }
    if (_user != null) note.userId = _user!.uid;
    final id = await _dbHelper.insertNote(note);
    note.id = id;

    if (note.reminderTime > 0) await ReminderHelper.scheduleReminder(note);
    AnalyticsHelper.noteCreated();

    if (_isFirebaseReady && _user != null) {
      try {
        await _syncToFirestore(note);
      } catch (e) {
        debugPrint('Sync after add failed: $e');
        lastError = 'تم الحفظ محلياً لكن فشلت المزامنة';
      }
    }

    await fetchNotes();
    NativeHelper.updateWidget();
    return note;
  }

  Future<void> updateNote(Note note, {bool autoTag = true}) async {
    if (autoTag && !note.isEncrypted) {
      final plain = note.content == '••••••••' ? _plainContentFor(note) : note.content;
      note.tags = TagHelper.generateTags(note.title, plain);
    }
    if (_user != null) note.userId = _user!.uid;
    await _dbHelper.updateNote(note);

    if (note.id != null) {
      if (note.reminderTime > 0) {
        await ReminderHelper.scheduleReminder(note);
      } else {
        await ReminderHelper.cancelReminder(note.id!);
      }
    }
    AnalyticsHelper.noteSaved();

    if (_isFirebaseReady && _user != null) {
      try {
        await _syncToFirestore(note);
      } catch (e) {
        debugPrint('Sync after update failed: $e');
        lastError = 'تم الحفظ محلياً لكن فشلت المزامنة';
      }
    }

    await fetchNotes();
    NativeHelper.updateWidget();
  }

  Future<void> deleteNote(int id) async {
    Note? note = _notes.cast<Note?>().firstWhere((n) => n?.id == id, orElse: () => null);
    note ??= await _dbHelper.getNoteById(id);
    if (note == null) return;

    note.isDeleted = true;
    note.deletedAt = DateTime.now().millisecondsSinceEpoch;
    note.isSynced = false;
    await _dbHelper.updateNote(note);

    if (_isFirebaseReady && _user != null) {
      await _syncToFirestore(note);
    }

    await fetchNotes();
    NativeHelper.updateWidget();
  }

  Future<bool> _syncToFirestore(Note note, {bool notify = true}) async {
    if (!_isFirebaseReady || _user == null || note.id == null) return false;
    bindUser(_user!.uid);

    if (notify) {
      _isSyncing = true;
      notifyListeners();
    }

    try {
      final docRef = _firestore
          .collection('users')
          .doc(_user!.uid)
          .collection('notes')
          .doc(note.id.toString());

      final plainTitle = note.title;
      final plainContent = _plainContentFor(note);
      final plainHtml = _plainHtmlFor(note);

      final encryptedMap = note.toMap();
      encryptedMap['title'] = EncryptionHelper.encryptText(plainTitle, forCloud: true);
      encryptedMap['content'] = EncryptionHelper.encryptText(plainContent, forCloud: true);
      if (plainHtml.isNotEmpty) {
        encryptedMap['contentHtml'] = EncryptionHelper.encryptText(plainHtml, forCloud: true);
      }
      if (note.tags.isNotEmpty) {
        encryptedMap['tags'] = EncryptionHelper.encryptText(note.tags, forCloud: true);
      }

      await docRef.set(encryptedMap);
      note.isSynced = true;
      await _dbHelper.updateNote(note);
      lastError = null;
      return true;
    } catch (e) {
      debugPrint('Firestore Sync Error: $e');
      lastError = 'تعذر مزامنة الملاحظات مع السحابة';
      note.isSynced = false;
      await _dbHelper.updateNote(note);
      return false;
    } finally {
      if (notify) {
        _isSyncing = false;
        notifyListeners();
      }
    }
  }

  Note _noteFromCloud(Map<String, dynamic> data, String docId) {
    bindUser(_user?.uid);

    if (data['title'] != null) {
      data['title'] = EncryptionHelper.decryptText(data['title'].toString(), fromCloud: true);
    }
    if (data['content'] != null) {
      data['content'] = EncryptionHelper.decryptText(data['content'].toString(), fromCloud: true);
    }
    if (data['tags'] != null && data['tags'].toString().isNotEmpty) {
      data['tags'] = EncryptionHelper.decryptText(data['tags'].toString(), fromCloud: true);
    }
    if (data['contentHtml'] != null && data['contentHtml'].toString().isNotEmpty) {
      var html = EncryptionHelper.decryptText(data['contentHtml'].toString(), fromCloud: true);
      final note = Note.fromMap({...data, 'contentHtml': html});
      if (note.isEncrypted && html.isNotEmpty) {
        note.contentHtml = EncryptionHelper.encryptText(html);
        note.content = '••••••••';
      }
      note.id = int.tryParse(docId) ?? note.id;
      note.isSynced = true;
      note.userId = _user?.uid;
      return note;
    }

    final cloudNote = Note.fromMap(data);
    cloudNote.id = int.tryParse(docId) ?? cloudNote.id;
    cloudNote.isSynced = true;
    cloudNote.userId = _user?.uid;
    return cloudNote;
  }

  Future<void> restoreNote(int id) async {
    Note? note = _trashNotes.cast<Note?>().firstWhere((n) => n?.id == id, orElse: () => null);
    note ??= await _dbHelper.getNoteById(id);
    if (note == null) return;

    note.isDeleted = false;
    note.deletedAt = 0;
    note.isSynced = false;
    await _dbHelper.updateNote(note);
    if (_isFirebaseReady && _user != null) await _syncToFirestore(note);
    await fetchTrashNotes();
    await fetchNotes();
    NativeHelper.updateWidget();
  }

  Future<void> permanentlyDeleteNote(int id) async {
    await _dbHelper.deleteNote(id);
    if (_isFirebaseReady && _user != null) {
      try {
        await _firestore.collection('users').doc(_user!.uid).collection('notes').doc(id.toString()).delete();
      } catch (e) {
        debugPrint('Firestore Delete Error: $e');
        lastError = 'تعذر حذف الملاحظة من السحابة';
      }
    }
    await fetchTrashNotes();
    NativeHelper.updateWidget();
  }

  Future<void> restoreAll() async {
    final snapshot = List<Note>.from(_trashNotes);
    for (var note in snapshot) {
      note.isDeleted = false;
      note.deletedAt = 0;
      await _dbHelper.updateNote(note);
      if (_isFirebaseReady && _user != null) await _syncToFirestore(note, notify: false);
    }
    await fetchTrashNotes();
    await fetchNotes();
    NativeHelper.updateWidget();
  }

  Future<void> clearTrash() async {
    final ids = _trashNotes.where((n) => n.id != null).map((n) => n.id!).toList();
    for (final id in ids) await permanentlyDeleteNote(id);
    await fetchTrashNotes();
  }

  Future<void> purgeExpiredTrash(int interval) async {
    if (interval == 2) return;
    final days = interval == 1 ? 7 : 30;
    final cutoff = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    await fetchTrashNotes();
    final expired = _trashNotes.where((n) {
      final deletedAt = n.deletedAt > 0 ? n.deletedAt : n.timestamp;
      return n.id != null && deletedAt < cutoff;
    }).map((n) => n.id!).toList();
    for (final id in expired) await permanentlyDeleteNote(id);
  }

  Future<void> syncAll() async {
    if (!_isFirebaseReady || _user == null) return;
    bindUser(_user!.uid);
    _isSyncing = true;
    lastError = null;
    notifyListeners();

    try {
      final localNotes = await _dbHelper.getNotes(deleted: false);
      for (var note in localNotes) {
        if (note.userId == null) {
          note.userId = _user!.uid;
          await _dbHelper.updateNote(note);
        }
        await _syncToFirestore(note, notify: false);
      }
      await syncFromCloud();
      await ReminderHelper.rescheduleAll(_notes);
    } catch (e) {
      debugPrint('Full Sync Error: $e');
      lastError = 'فشلت المزامنة الكاملة';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncFromCloud() async {
    if (!_isFirebaseReady || _user == null) return;
    bindUser(_user!.uid);

    try {
      final snapshot = await _firestore.collection('users').doc(_user!.uid).collection('notes').get();

      for (var doc in snapshot.docs) {
        final cloudNote = _noteFromCloud(Map<String, dynamic>.from(doc.data()), doc.id);

        Note? existing;
        if (cloudNote.id != null) {
          existing = await _dbHelper.getNoteById(cloudNote.id!);
        }

        if (existing == null) {
          await _dbHelper.insertNote(cloudNote);
        } else if (cloudNote.timestamp >= existing.timestamp) {
          cloudNote.id = existing.id;
          await _dbHelper.updateNote(cloudNote);
        }
      }
      await fetchNotes();
      await fetchTrashNotes();
      lastError = null;
    } catch (e) {
      debugPrint('Firestore Download Error: $e');
      lastError = 'تعذر جلب الملاحظات من السحابة';
    }
  }

  List<String> get categories => ['عام', 'خاص', 'شخصي'];
}
