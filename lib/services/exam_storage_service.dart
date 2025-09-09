import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brie_fly/models/exam_record.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExamStorageService {
  static const String _key = 'exam_records_v1';

  // Realtime sync management (singletons)
  static StreamSubscription<User?>? _authSub;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _examSub;
  static bool _realtimeInitialized = false;
  static final StreamController<void> _changeController = StreamController<void>.broadcast();
  Stream<void> get changes => _changeController.stream;

  ExamStorageService() {
    // Initialize realtime sync once per app run
    if (!_realtimeInitialized) {
      _realtimeInitialized = true;
      _ensureRealtimeSync();
    }
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  CollectionReference<Map<String, dynamic>>? get _col =>
      _uid == null ? null : FirebaseFirestore.instance.collection('users').doc(_uid).collection('exams');

  // Ensure we listen to auth changes and keep a live listener on exams
  static void _ensureRealtimeSync() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) async {
      // Tear down previous listener
      await _examSub?.cancel();
      _examSub = null;

      if (user == null) {
        return; // signed out -> no cloud listener
      }

      final col = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('exams');

      // Optional: on sign-in, push local to cloud first, then we will receive merged remote via listener
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_key);
        if (raw != null && raw.isNotEmpty) {
          final local = (json.decode(raw) as List).map((e) => ExamRecord.fromJson(e as Map<String, dynamic>)).toList();
          for (final r in local) {
            await col.doc(r.id).set(r.toJson(), SetOptions(merge: true));
          }
        }
      } catch (_) {}

      _examSub = col.snapshots().listen((snap) async {
        // Treat Firestore snapshot as authoritative so deletions propagate
        try {
          final remoteRecords = snap.docs.map((d) => ExamRecord.fromJson(d.data())).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_key, json.encode(remoteRecords.map((e) => e.toJson()).toList()));
          _changeController.add(null);
        } catch (_) {
          // ignore
        }
      });
    });
  }

  Future<List<ExamRecord>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (json.decode(raw) as List)
          .map((e) => ExamRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      // Deduplicate strictly by id to avoid merging different sessions
      final Map<String, List<ExamRecord>> groups = {};
      for (final r in list) {
        groups.putIfAbsent(r.id, () => []).add(r);
      }
      final List<ExamRecord> deduped = [];
      bool changed = false;
      for (final entry in groups.entries) {
        final items = entry.value;
        if (items.length == 1) {
          deduped.add(items.first);
          continue;
        }
        changed = true;
        // Keep the most recent snapshot by date for this exam id
        items.sort((a, b) => b.date.compareTo(a.date));
        deduped.add(items.first);
      }
      // Sort overall list by date desc
      deduped.sort((a, b) => b.date.compareTo(a.date));
      // Persist cleanup if any changes
      if (changed) {
        final jsonList = deduped.map((e) => e.toJson()).toList();
        await prefs.setString(_key, json.encode(jsonList));
      }
      return deduped;
    } catch (_) {
      return [];
    }
  }

  Future<void> upsert(ExamRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getAll();
    final idx = existing.indexWhere((e) => e.id == record.id);
    if (idx >= 0) {
      final prev = existing[idx];
      // Merge policy to protect in-progress remainingSeconds and progress from accidental zero overwrites
      if (!record.completed && !prev.completed) {
        final keepRemaining = (record.remainingSeconds <= 0 && prev.remainingSeconds > 0)
            ? prev.remainingSeconds
            : record.remainingSeconds;
        final merged = ExamRecord(
          id: record.id,
          // Use the newer date
          date: record.date.isAfter(prev.date) ? record.date : prev.date,
          durationMinutes: record.durationMinutes,
          score: record.score,
          total: record.total,
          categories: record.categories,
          questions: record.questions,
          userAnswers: record.userAnswers,
          completed: false,
          remainingSeconds: keepRemaining,
          currentIndex: (record.currentIndex >= prev.currentIndex) ? record.currentIndex : prev.currentIndex,
        );
        existing[idx] = merged;
      } else {
        existing[idx] = record;
      }
    } else {
      existing.insert(0, record);
    }
    final jsonList = existing.map((e) => e.toJson()).toList();
    await prefs.setString(_key, json.encode(jsonList));
    _changeController.add(null);

    // Cloud sync (best-effort)
    try {
      final col = _col;
      if (col != null) {
        await col.doc(record.id).set(record.toJson(), SetOptions(merge: true));
      }
    } catch (_) {}
  }

  // Backwards-compatible alias
  Future<void> save(ExamRecord record) => upsert(record);

  Future<void> deleteById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    list.removeWhere((e) => e.id == id);
    final jsonList = list.map((e) => e.toJson()).toList();
    await prefs.setString(_key, json.encode(jsonList));
    _changeController.add(null);

    // Cloud sync delete (best-effort)
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

    // Cloud: delete all user exams (best-effort)
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

  /// Pull from Firestore and merge into local storage. Use same dedupe rules (by id, keep latest date).
  Future<void> syncFromCloud() async {
    final col = _col;
    if (col == null) return;
    try {
      final remote = await col.get();
      final remoteRecords = remote.docs.map((d) => ExamRecord.fromJson(d.data())).toList();
      if (remoteRecords.isEmpty) return;
      final local = await getAll();
      // Index by id, keep latest by date
      final Map<String, ExamRecord> map = {for (final r in local) r.id: r};
      for (final r in remoteRecords) {
        final prev = map[r.id];
        if (prev == null || r.date.isAfter(prev.date)) {
          map[r.id] = r;
        }
      }
      final merged = map.values.toList()..sort((a, b) => b.date.compareTo(a.date));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, json.encode(merged.map((e) => e.toJson()).toList()));
    } catch (_) {
      // ignore
    }
  }

  /// Push all local exams to Firestore (best-effort). Useful right after login on a new device.
  Future<void> pushAllToCloud() async {
    final col = _col;
    if (col == null) return;
    try {
      final local = await getAll();
      for (final r in local) {
        await col.doc(r.id).set(r.toJson(), SetOptions(merge: true));
      }
    } catch (_) {
      // ignore
    }
  }
}

