import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';

class ShareLinkHelper {
  static bool get _ready => Firebase.apps.isNotEmpty;

  /// Creates a temporary public share document (plain text only — refuses encrypted notes).
  static Future<String?> createProtectedLink(Note note, {Duration ttl = const Duration(days: 7)}) async {
    if (!_ready) return null;
    if (note.isEncrypted) {
      throw StateError('لا يمكن مشاركة مذكرة مشفّرة برابط');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('يلزم تسجيل الدخول لمشاركة رابط');
    }

    final expiresAt = DateTime.now().add(ttl);
    final doc = await FirebaseFirestore.instance.collection('shared_notes').add({
      'ownerId': user.uid,
      'title': note.title,
      'content': note.content,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'noteId': note.id,
    });

    // Deep-link style URL — opens in browser / app if hosted; also shareable as plain id.
    final link = 'https://mysmartnotes-8459e.web.app/share/${doc.id}';
    await SharePlus.instance.share(
      ShareParams(
        text: 'مذكرة من مفكرتي (تنتهي ${expiresAt.toIso8601String().substring(0, 10)}):\n$link',
        subject: note.title,
      ),
    );
    return link;
  }

  static Future<Map<String, dynamic>?> fetchShared(String shareId) async {
    if (!_ready) return null;
    try {
      final snap = await FirebaseFirestore.instance.collection('shared_notes').doc(shareId).get();
      if (!snap.exists) return null;
      final data = snap.data()!;
      final expires = data['expiresAt'];
      if (expires is Timestamp && expires.toDate().isBefore(DateTime.now())) {
        return null;
      }
      return data;
    } catch (e) {
      debugPrint('fetchShared failed: $e');
      return null;
    }
  }
}
