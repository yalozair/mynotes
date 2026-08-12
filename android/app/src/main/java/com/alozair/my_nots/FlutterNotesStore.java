package com.alozair.my_nots;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;

/**
 * Reads/writes the same SQLite file Flutter (sqflite) uses so the
 * home widget and floating bubble stay in sync with the app.
 */
public final class FlutterNotesStore {
    private FlutterNotesStore() {}

    public static class NotePreview {
        public final String title;
        public final String content;

        public NotePreview(String title, String content) {
            this.title = title;
            this.content = content;
        }
    }

    private static SQLiteDatabase open(Context context, boolean writable) {
        String path = context.getDatabasePath("notes.db").getPath();
        int flags = writable
                ? SQLiteDatabase.OPEN_READWRITE
                : SQLiteDatabase.OPEN_READONLY;
        return SQLiteDatabase.openDatabase(path, null, flags);
    }

    public static NotePreview getLatestNote(Context context) {
        SQLiteDatabase db = null;
        Cursor cursor = null;
        try {
            db = open(context, false);
            cursor = db.rawQuery(
                    "SELECT title, content, isEncrypted FROM notes WHERE isDeleted = 0 ORDER BY timestamp DESC LIMIT 1",
                    null
            );
            if (cursor.moveToFirst()) {
                String title = cursor.getString(0);
                boolean encrypted = cursor.getInt(2) == 1;
                String content = encrypted ? "ملاحظة مشفرة" : cursor.getString(1);
                return new NotePreview(title != null ? title : "", content != null ? content : "");
            }
        } catch (Exception ignored) {
            // Database may not exist yet on first launch.
        } finally {
            if (cursor != null) cursor.close();
            if (db != null) db.close();
        }
        return null;
    }

    public static boolean insertQuickNote(Context context, String title, String content) {
        SQLiteDatabase db = null;
        try {
            db = open(context, true);
            long now = System.currentTimeMillis();
            ContentValues values = new ContentValues();
            values.put("title", title);
            values.put("content", content);
            values.put("contentHtml", "");
            values.put("fontSize", 20);
            values.put("isBold", 0);
            values.put("isUnderlined", 0);
            values.put("color", "Black");
            values.put("fontName", "Cairo");
            values.put("isRtl", 1);
            values.put("isCenter", 0);
            values.put("isLtr", 0);
            values.put("timestamp", now);
            values.put("isDeleted", 0);
            values.put("reminderTime", 0);
            values.put("category", "عام");
            values.put("cardColor", 0);
            values.put("isEncrypted", 0);
            values.put("isSynced", 0);
            return db.insert("notes", null, values) != -1;
        } catch (Exception e) {
            return false;
        } finally {
            if (db != null) db.close();
        }
    }
}
