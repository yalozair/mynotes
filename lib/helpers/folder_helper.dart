import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FolderMeta {
  final String name;
  final int color;
  final String icon;

  const FolderMeta({
    required this.name,
    this.color = 0xFF26C6DA,
    this.icon = 'folder',
  });

  Map<String, dynamic> toJson() => {'name': name, 'color': color, 'icon': icon};

  factory FolderMeta.fromJson(Map<String, dynamic> json) => FolderMeta(
        name: json['name']?.toString() ?? 'الافتراضي',
        color: json['color'] is int ? json['color'] as int : int.tryParse('${json['color']}') ?? 0xFF26C6DA,
        icon: json['icon']?.toString() ?? 'folder',
      );

  IconData get iconData {
    switch (icon) {
      case 'work':
        return Icons.work_outline;
      case 'home':
        return Icons.home_outlined;
      case 'school':
        return Icons.school_outlined;
      case 'favorite':
        return Icons.favorite_outline;
      case 'star':
        return Icons.star_outline;
      case 'book':
        return Icons.menu_book_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  static const icons = ['folder', 'work', 'home', 'school', 'favorite', 'star', 'book'];
  static const palette = [
    0xFF26C6DA,
    0xFF42A5F5,
    0xFF66BB6A,
    0xFFFFA726,
    0xFFEF5350,
    0xFFAB47BC,
    0xFF78909C,
  ];
}

class FolderHelper {
  static const _key = 'folder_meta_v1';

  static Future<List<FolderMeta>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final list = <FolderMeta>[
      const FolderMeta(name: 'الافتراضي'),
    ];
    for (final e in raw) {
      try {
        final meta = FolderMeta.fromJson(Map<String, dynamic>.from(jsonDecode(e) as Map));
        if (meta.name == 'الافتراضي') continue;
        list.add(meta);
      } catch (_) {}
    }
    return list;
  }

  static Future<void> upsert(FolderMeta meta) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final updated = <String>[];
    var found = false;
    for (final e in raw) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(e) as Map);
        if (map['name'] == meta.name) {
          updated.add(jsonEncode(meta.toJson()));
          found = true;
        } else {
          updated.add(e);
        }
      } catch (_) {}
    }
    if (!found && meta.name != 'الافتراضي') {
      updated.add(jsonEncode(meta.toJson()));
    }
    await prefs.setStringList(_key, updated);
  }

  static Future<void> delete(String name) async {
    if (name == 'الافتراضي') return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((e) {
      try {
        return (jsonDecode(e) as Map)['name'] == name;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_key, raw);
  }
}
