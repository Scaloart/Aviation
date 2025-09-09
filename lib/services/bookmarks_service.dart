import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brie_fly/models/qcm_question.dart';
import 'package:brie_fly/models/question.dart' as qr;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookmarkItem {
  final String id; // derived from question content
  final String category;
  final String question;
  final List<String> options;
  final DateTime dateAdded;
  final String? note;
  final int correctIndex;
  // New fields for supporting both QCM and QR
  final String type; // 'qcm' or 'qr'
  final String? answerText; // for QR

  BookmarkItem({
    required this.id,
    required this.category,
    required this.question,
    required this.options,
    required this.dateAdded,
    this.note,
    required this.correctIndex,
    this.type = 'qcm',
    this.answerText,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'question': question,
        'options': options,
        'dateAdded': dateAdded.toIso8601String(),
        'note': note,
        'correctIndex': correctIndex,
        'type': type,
        'answerText': answerText,
      };

  static BookmarkItem fromJson(Map<String, dynamic> json) => BookmarkItem(
        id: (json['id'] ?? '') as String,
        category: (json['category'] ?? '') as String,
        question: (json['question'] ?? '') as String,
        options: ((json['options'] as List?)?.map((e) => e?.toString() ?? '')?.where((s) => s.isNotEmpty).toList()) ?? const [],
        dateAdded: _parseDate(json['dateAdded']),
        note: json['note'] as String?,
        correctIndex: _extractCorrectIndex(json),
        type: (json['type'] as String?) ?? _inferType(json),
        answerText: json['answerText'] as String?,
      );

  static DateTime _parseDate(dynamic v) {
    if (v is String) {
      return DateTime.tryParse(v) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static int _extractCorrectIndex(Map<String, dynamic> json) {
    final ci = json['correctIndex'];
    if (ci is int) return ci;
    if (ci is num) return ci.toInt();
    if (ci is String) {
      final parsed = int.tryParse(ci);
      if (parsed != null) return parsed;
    }
    // Back-compat: id format ends with |<correctIndex>
    final id = json['id'] as String?;
    if (id != null && id.contains('|')) {
      final last = id.split('|').last;
      final parsed = int.tryParse(last);
      if (parsed != null) return parsed;
    }
    return -1;
  }

  static String _inferType(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id != null && id.startsWith('qr|')) return 'qr';
    return 'qcm';
  }
}

class BookmarksService {
  static const String _key = 'bookmarks_v1';
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  static StreamSubscription<User?>? _authSub;
  static bool _realtimeInitialized = false;
  static final StreamController<void> _changeController = StreamController<void>.broadcast();
  Stream<void> get changes => _changeController.stream;

  BookmarksService() {
    if (!_realtimeInitialized) {
      _realtimeInitialized = true;
      _ensureRealtime();
    }
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  CollectionReference<Map<String, dynamic>>? get _col =>
      _uid == null ? null : FirebaseFirestore.instance.collection('users').doc(_uid).collection('bookmarks');

  String _sanitizeIdPart(String s) => s.replaceAll('/', '_');

  String qidFor(QcmQuestion q) =>
      'qcm|${_sanitizeIdPart(q.category)}|${_sanitizeIdPart(q.question)}|${q.options.map(_sanitizeIdPart).join('||')}|${q.correctOptionIndex}';

  String qidForQr(qr.Question q) => 'qr|${_sanitizeIdPart(q.category)}|${_sanitizeIdPart(q.question)}|${_sanitizeIdPart(q.answer)}';

  // Legacy id (pre-type prefix) for QCM items
  String _legacyQcmIdFor(QcmQuestion q) =>
      '${q.category}|${q.question}|${q.options.join('||')}|${q.correctOptionIndex}';

  Future<List<BookmarkItem>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (json.decode(raw) as List)
          .map((e) => BookmarkItem.fromJson(e as Map<String, dynamic>))
          .toList();
      // Sort by date desc
      list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<bool> isBookmarked(String id) async {
    final all = await getAll();
    return all.any((e) => e.id == id);
  }

  Future<String?> noteFor(String id) async {
    final all = await getAll();
    for (final e in all) {
      if (e.id == id) return e.note;
    }
    return null;
  }

  Future<void> upsert(BookmarkItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    final idx = list.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      list[idx] = item;
    } else {
      list.insert(0, item);
    }
    await prefs.setString(_key, json.encode(list.map((e) => e.toJson()).toList()));
    _changeController.add(null);

    // Cloud sync
    try {
      final col = _col;
      if (col != null) {
        await col.doc(item.id).set(item.toJson(), SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> toggleBookmarkQr(qr.Question q, {String? note}) async {
    final id = qidForQr(q);
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    final idx = list.indexWhere((e) => e.id == id);
    final bool remove = idx >= 0 && (note == null || note.isEmpty);
    if (remove) {
      list.removeAt(idx);
    } else {
      final item = BookmarkItem(
        id: id,
        category: q.category,
        question: q.question,
        options: const [],
        dateAdded: DateTime.now(),
        note: note ?? (idx >= 0 ? list[idx].note : null),
        correctIndex: -1,
        type: 'qr',
        answerText: q.answer,
      );
      if (idx >= 0) {
        list[idx] = item;
      } else {
        list.insert(0, item);
      }
    }
    await prefs.setString(_key, json.encode(list.map((e) => e.toJson()).toList()));

    // Cloud sync
    try {
      final col = _col;
      if (col != null) {
        if (remove) {
          await col.doc(id).delete();
        } else {
          final item = list.firstWhere((e) => e.id == id, orElse: () => BookmarkItem(
                id: id,
                category: q.category,
                question: q.question,
                options: const [],
                dateAdded: DateTime.now(),
                note: note,
                correctIndex: -1,
                type: 'qr',
                answerText: q.answer,
              ));
          await col.doc(id).set(item.toJson(), SetOptions(merge: true));
        }
      }
    } catch (_) {}
  }

  Future<void> toggleBookmark(QcmQuestion q, {String? note}) async {
    final id = qidFor(q);
    final legacyId = _legacyQcmIdFor(q);
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    int idx = list.indexWhere((e) => e.id == id);
    // Check legacy id too
    if (idx < 0) idx = list.indexWhere((e) => e.id == legacyId);
    final bool remove = idx >= 0 && (note == null || note.isEmpty);
    if (remove) {
      list.removeAt(idx);
    } else {
      final item = BookmarkItem(
        id: id,
        category: q.category,
        question: q.question,
        options: q.options,
        dateAdded: DateTime.now(),
        note: note ?? (idx >= 0 ? list[idx].note : null),
        correctIndex: q.correctOptionIndex,
        type: 'qcm',
      );
      if (idx >= 0) {
        list[idx] = item; // migrate legacy id to new id on save
      } else {
        list.insert(0, item);
      }
    }
    await prefs.setString(_key, json.encode(list.map((e) => e.toJson()).toList()));

    // Cloud sync
    try {
      final col = _col;
      if (col != null) {
        if (remove) {
          await col.doc(id).delete();
        } else {
          final item = list.firstWhere((e) => e.id == id, orElse: () => BookmarkItem(
                id: id,
                category: q.category,
                question: q.question,
                options: q.options,
                dateAdded: DateTime.now(),
                note: note,
                correctIndex: q.correctOptionIndex,
                type: 'qcm',
              ));
          await col.doc(id).set(item.toJson(), SetOptions(merge: true));
        }
      }
    } catch (_) {}
  }

  Future<void> updateNote(String id, String? note) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    final idx = list.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      final prev = list[idx];
      list[idx] = BookmarkItem(
        id: prev.id,
        category: prev.category,
        question: prev.question,
        options: prev.options,
        dateAdded: prev.dateAdded,
        note: note,
        correctIndex: prev.correctIndex,
        type: prev.type,
        answerText: prev.answerText,
      );
      await prefs.setString(_key, json.encode(list.map((e) => e.toJson()).toList()));
      _changeController.add(null);
      // Cloud sync
      try {
        final col = _col;
        if (col != null) {
          await col.doc(id).set(list[idx].toJson(), SetOptions(merge: true));
        }
      } catch (_) {}
    }
  }

  Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    list.removeWhere((e) => e.id == id);
    await prefs.setString(_key, json.encode(list.map((e) => e.toJson()).toList()));
    // Cloud sync
    try {
      final col = _col;
      if (col != null) {
        await col.doc(id).delete();
      }
    } catch (_) {}
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _changeController.add(null);
    // Cloud: delete all bookmarks
    try {
      final col = _col;
      if (col != null) {
        final snap = await col.get();
        for (final d in snap.docs) {
          await d.reference.delete();
        }
      }
    } catch (_) {}
  }

  /// Pull from Firestore and merge into local storage. Prefer latest dateAdded by id.
  Future<void> syncFromCloud() async {
    final col = _col;
    if (col == null) return;
    try {
      final remote = await col.get();
      final remoteItems = remote.docs.map((d) => BookmarkItem.fromJson(d.data())).toList();
      await _persistExact(remoteItems);
    } catch (_) {
      // ignore
    }
  }

  /// Push all local bookmarks to Firestore (best-effort). Useful right after login on a new device.
  Future<void> pushAllToCloud() async {
    final col = _col;
    if (col == null) return;
    try {
      final local = await getAll();
      for (final b in local) {
        await col.doc(b.id).set(b.toJson(), SetOptions(merge: true));
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> startRealtime() async {
    await stopRealtime();
    final col = _col;
    if (col == null) return;
    _sub = col.snapshots().listen((snap) async {
      try {
        // Treat remote snapshot as authoritative, so deletions propagate
        final items = snap.docs.map((d) => BookmarkItem.fromJson(d.data())).toList();
        await _persistExact(items);
        _changeController.add(null);
      } catch (_) {}
    });
  }

  Future<void> stopRealtime() async {
    await _sub?.cancel();
    _sub = null;
  }

  static void _ensureRealtime() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) async {
      // Stop any existing bookmarks listener when auth changes
      await _sub?.cancel();
      _sub = null;

      if (user == null) {
        return; // signed out -> no cloud listener
      }

      // Push local bookmarks up first (best-effort), then start realtime listener
      try {
        await BookmarksService().pushAllToCloud();
      } catch (_) {}

      try {
        await BookmarksService().startRealtime();
      } catch (_) {}
    });
  }

  // Merge remote items into local cache and persist
  Future<void> _mergeAndPersist(List<BookmarkItem> remoteItems) async {
    final local = await getAll();
    final Map<String, BookmarkItem> map = {for (final b in local) b.id: b};
    for (final b in remoteItems) {
      final prev = map[b.id];
      if (prev == null || b.dateAdded.isAfter(prev.dateAdded)) {
        map[b.id] = b;
      }
    }
    final merged = map.values.toList()..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(merged.map((e) => e.toJson()).toList()));
  }

  // Replace local cache exactly with provided items (authoritative from remote)
  Future<void> _persistExact(List<BookmarkItem> items) async {
    final sorted = items.toList()..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(sorted.map((e) => e.toJson()).toList()));
  }
}

