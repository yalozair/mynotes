import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import '../models/note_revision.dart';

class DBHelper {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<void> closeDb() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  Future<Database> initDb() async {
    final prefs = await SharedPreferences.getInstance();
    String? customPath = prefs.getString('custom_db_path');

    String path;
    if (customPath != null && customPath.isNotEmpty) {
      path = join(customPath, "notes.db");
    } else if (Platform.isWindows) {
      final String userHome = Platform.environment['USERPROFILE'] ?? '';
      path = join(userHome, "Documents", "MyNotesFlutter", "database", "notes.db");
    } else {
      path = join(await getDatabasesPath(), "notes.db");
    }

    debugPrint("DATABASE_STORAGE_PATH: $path");
    await Directory(dirname(path)).create(recursive: true);

    return openDatabase(path, version: 9, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE notes ADD COLUMN userId TEXT");
    }
    if (oldVersion < 5) {
      await db.execute("ALTER TABLE notes ADD COLUMN isSynced INTEGER DEFAULT 0");
    }
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE notes ADD COLUMN deletedAt INTEGER DEFAULT 0");
    }
    if (oldVersion < 7) {
      await db.execute("ALTER TABLE notes ADD COLUMN tags TEXT DEFAULT ''");
      await db.execute("ALTER TABLE notes ADD COLUMN reminderRepeat INTEGER DEFAULT 0");
    }
    if (oldVersion < 8) {
      await db.execute("ALTER TABLE notes ADD COLUMN isPinned INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE notes ADD COLUMN folder TEXT DEFAULT 'الافتراضي'");
      await db.execute("ALTER TABLE notes ADD COLUMN folderColor INTEGER DEFAULT ${0xFF26C6DA}");
      await db.execute("ALTER TABLE notes ADD COLUMN folderIcon TEXT DEFAULT 'folder'");
      await db.execute("ALTER TABLE notes ADD COLUMN pinHash TEXT");
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS note_revisions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          noteId INTEGER NOT NULL,
          title TEXT,
          content TEXT,
          contentHtml TEXT,
          savedAt INTEGER
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        content TEXT,
        contentHtml TEXT,
        fontSize INTEGER,
        isBold INTEGER,
        isUnderlined INTEGER,
        color TEXT,
        fontName TEXT,
        isRtl INTEGER,
        isCenter INTEGER,
        isLtr INTEGER,
        timestamp INTEGER,
        isDeleted INTEGER,
        deletedAt INTEGER DEFAULT 0,
        reminderTime INTEGER,
        reminderRepeat INTEGER DEFAULT 0,
        tags TEXT DEFAULT '',
        category TEXT,
        cardColor INTEGER,
        isEncrypted INTEGER,
        userId TEXT,
        isSynced INTEGER DEFAULT 0,
        isPinned INTEGER DEFAULT 0,
        folder TEXT DEFAULT 'الافتراضي',
        folderColor INTEGER DEFAULT ${0xFF26C6DA},
        folderIcon TEXT DEFAULT 'folder',
        pinHash TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE note_revisions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        noteId INTEGER NOT NULL,
        title TEXT,
        content TEXT,
        contentHtml TEXT,
        savedAt INTEGER
      )
    ''');
  }

  Future<int> insertNote(Note note) async {
    final dbClient = await db;
    return await dbClient.insert("notes", note.toMap());
  }

  Future<List<Note>> getNotes({bool deleted = false}) async {
    final dbClient = await db;
    final maps = await dbClient.query(
      "notes",
      where: "isDeleted = ?",
      whereArgs: [deleted ? 1 : 0],
      orderBy: "isPinned DESC, timestamp DESC",
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<Note?> getNoteById(int id) async {
    final dbClient = await db;
    final maps = await dbClient.query("notes", where: "id = ?", whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }

  Future<int> updateNote(Note note) async {
    final dbClient = await db;
    return await dbClient.update("notes", note.toMap(), where: "id = ?", whereArgs: [note.id]);
  }

  Future<int> deleteNote(int id) async {
    final dbClient = await db;
    await dbClient.delete("note_revisions", where: "noteId = ?", whereArgs: [id]);
    return await dbClient.delete("notes", where: "id = ?", whereArgs: [id]);
  }

  Future<void> saveRevision(NoteRevision revision, {int keepLast = 20}) async {
    final dbClient = await db;
    await dbClient.insert('note_revisions', revision.toMap());
    final rows = await dbClient.query(
      'note_revisions',
      where: 'noteId = ?',
      whereArgs: [revision.noteId],
      orderBy: 'savedAt DESC',
    );
    if (rows.length > keepLast) {
      for (final old in rows.skip(keepLast)) {
        await dbClient.delete('note_revisions', where: 'id = ?', whereArgs: [old['id']]);
      }
    }
  }

  Future<List<NoteRevision>> getRevisions(int noteId) async {
    final dbClient = await db;
    final maps = await dbClient.query(
      'note_revisions',
      where: 'noteId = ?',
      whereArgs: [noteId],
      orderBy: 'savedAt DESC',
    );
    return maps.map(NoteRevision.fromMap).toList();
  }
}
