package com.alozair.my_nots.database;

import androidx.room.Entity;
import androidx.room.PrimaryKey;

@Entity(tableName = "notes")
public class Note {
    @PrimaryKey(autoGenerate = true)
    public int id;
    
    public String title;
    public String content;
    public String contentHtml;
    public int fontSize;
    public boolean isBold;
    public boolean isUnderlined;
    public String color;
    public String fontName;
    public boolean isRtl;
    public boolean isCenter;
    public boolean isLtr;
    public long timestamp;

    public boolean isDeleted;
    public long reminderTime;
    public String category;
    public int cardColor;
    public boolean isEncrypted;

    public Note() {}

    public Note(String title, String content, int fontSize, boolean isBold, boolean isUnderlined, 
                String color, String fontName, boolean isRtl, boolean isCenter, boolean isLtr) {
        this.title = title;
        this.content = content;
        this.fontSize = fontSize;
        this.isBold = isBold;
        this.isUnderlined = isUnderlined;
        this.color = color;
        this.fontName = fontName;
        this.isRtl = isRtl;
        this.isCenter = isCenter;
        this.isLtr = isLtr;
        this.timestamp = System.currentTimeMillis();
        this.isDeleted = false;
        this.cardColor = 0;
    }
}
