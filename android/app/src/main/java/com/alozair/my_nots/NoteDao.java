package com.alozair.my_nots.database;

import androidx.room.Dao;
import androidx.room.Delete;
import androidx.room.Insert;
import androidx.room.OnConflictStrategy;
import androidx.room.Query;
import androidx.room.Update;

import java.util.List;

@Dao
public interface NoteDao {
    @Insert
    void insert(Note note);

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insertAll(List<Note> notes);

    @Update
    void update(Note note);

    @Delete
    void delete(Note note);

    @Query("SELECT * FROM notes WHERE isDeleted = 0 ORDER BY timestamp DESC")
    List<Note> getAllNotes();

    @Query("SELECT * FROM notes WHERE isDeleted = 1 ORDER BY timestamp DESC")
    List<Note> getDeletedNotes();

    @Query("SELECT * FROM notes WHERE (title LIKE :searchQuery OR content LIKE :searchQuery) AND isDeleted = :deleted ORDER BY timestamp DESC")
    List<Note> searchNotes(String searchQuery, boolean deleted);

    @Query("SELECT * FROM notes WHERE title = :title LIMIT 1")
    Note getNoteByTitle(String title);

    @Query("SELECT * FROM notes WHERE id = :id LIMIT 1")
    Note getNoteById(int id);

    @Query("DELETE FROM notes WHERE isDeleted = 1 AND timestamp < :timestamp")
    void deleteNotesFromTrashOlderThan(long timestamp);

    @Query("SELECT * FROM notes WHERE category = :category AND isDeleted = 0 ORDER BY timestamp DESC")
    List<Note> getNotesByCategory(String category);

    @Query("SELECT DISTINCT category FROM notes WHERE isDeleted = 0")
    List<String> getAllCategories();

    @Query("SELECT COUNT(*) FROM notes WHERE isDeleted = 0")
    int getTotalNotesCount();

    @Query("SELECT COALESCE(SUM(LENGTH(content)), 0) FROM notes WHERE isDeleted = 0")
    int getTotalWordCount();
}
