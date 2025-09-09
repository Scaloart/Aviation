import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/models/qcm_question.dart';
import 'package:brie_fly/screens/qcm_results_screen.dart';
import 'package:brie_fly/widgets/background_container.dart';

import 'package:brie_fly/screens/qcm_category_screen.dart';
import 'package:brie_fly/services/bookmarks_service.dart';
import 'package:brie_fly/screens/bookmarks_screen.dart';
import 'package:brie_fly/models/exam_record.dart';
import 'package:brie_fly/screens/cpl_screen.dart';
import 'package:brie_fly/services/exam_storage_service.dart';
import 'package:brie_fly/services/ads/interstitial_ad_service.dart';

class QcmQuizScreen extends StatefulWidget {
  final List<QcmQuestion> questions;
  final QcmMode mode;
  final int? examDurationMinutes; // for exam mode
  final List<String>? selectedCategories; // metadata for history
  final ExamRecord? resumeRecord; // optional: resume an in-progress exam

  const QcmQuizScreen({
    super.key,
    required this.questions,
    required this.mode,
    this.examDurationMinutes,
    this.selectedCategories,
    this.resumeRecord,
  });

  @override
  State<QcmQuizScreen> createState() => _QcmQuizScreenState();
}

class _QcmQuizScreenState extends State<QcmQuizScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedOptionIndex;
  bool _answered = false;
  late List<int?> _userAnswers;
  // Study mode: bookmarks/notes state for current question
  bool _isBookmarked = false;
  String? _currentNote;

  // Exam timer
  Timer? _timer;
  int _remainingSeconds = 0;
  int _tick = 0;

  final ExamStorageService _storage = ExamStorageService();
  final BookmarksService _bookmarks = BookmarksService();
  // Stable exam identity for the session
  late final String _examId;
  late final DateTime _examStartDate;
  bool _finished = false;
  // Control whether autosaves should happen on dispose/lifecycle
  bool _shouldAutoSave = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userAnswers = List<int?>.filled(widget.questions.length, null);
    // If resuming an exam, hydrate state. Resume strictly when remainingSeconds > 0.
    if (widget.mode == QcmMode.exam && widget.resumeRecord != null) {
      _currentIndex = widget.resumeRecord!.currentIndex.clamp(0, widget.questions.length - 1);
      _userAnswers = List<int?>.from(widget.resumeRecord!.userAnswers);
      // Recompute score from existing answers
      _score = 0;
      for (int i = 0; i < _userAnswers.length; i++) {
        final ans = _userAnswers[i];
        if (ans != null && ans == widget.questions[i].correctOptionIndex) _score++;
      }
      _remainingSeconds = widget.resumeRecord!.remainingSeconds;
      if (_remainingSeconds > 0) {
        // Maintain the same identity as the record being resumed
        _examId = widget.resumeRecord!.id;
        _examStartDate = widget.resumeRecord!.date;
        debugPrint('[QCM] Resume exam id=${_examId} remaining=${_remainingSeconds}s index=${_currentIndex} date=${_examStartDate.toIso8601String()}');
        // Persist immediately so My Exams reflects the correct remaining time
        _persistInProgress();
      } else if ((widget.examDurationMinutes ?? 0) > 0) {
        // Fallback to a new session if record isn't resume-able
        final now = DateTime.now();
        _examId = 'exam_${now.millisecondsSinceEpoch}';
        _examStartDate = now;
        _remainingSeconds = widget.examDurationMinutes! * 60;
        debugPrint('[QCM] Resume fallback -> new session id=${_examId} remaining=${_remainingSeconds}s');
      }
    } else if (widget.mode == QcmMode.exam && (widget.examDurationMinutes ?? 0) > 0) {
      _remainingSeconds = widget.examDurationMinutes! * 60;
      // New exam session identity
      final now = DateTime.now();
      _examId = 'exam_${now.millisecondsSinceEpoch}';
      _examStartDate = now;
      debugPrint('[QCM] New exam session id=${_examId} remaining=${_remainingSeconds}s');
    }
    if (widget.mode == QcmMode.exam && _remainingSeconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds <= 0) {
            t.cancel();
            _finishExam();
          }
        });
        // Autosave every second to ensure accurate remaining time
        if (_remainingSeconds > 0) {
          _tick++;
          _persistInProgress();
        }
      });
    }
    // Initialize bookmarks/notes state for Study mode
    if (widget.mode == QcmMode.study) {
      // Schedule after first frame to ensure context/state is ready
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBookmarkState());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    // Best-effort snapshot to keep remaining time if not finished
    if (widget.mode == QcmMode.exam && !_finished && _remainingSeconds > 0 && _shouldAutoSave) {
      _persistInProgress();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.mode != QcmMode.exam) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // App going to background: stop timer and save snapshot (if allowed)
      _timer?.cancel();
      if (_shouldAutoSave && _remainingSeconds > 0) {
        _persistInProgress();
      }
    } else if (state == AppLifecycleState.resumed) {
      // App back: restart timer if still time left
      if (_remainingSeconds > 0 && _timer == null && !_finished) {
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) return;
          setState(() {
            _remainingSeconds--;
            if (_remainingSeconds <= 0) {
              t.cancel();
              _finishExam();
            }
          });
          if (_remainingSeconds > 0) {
            _persistInProgress();
          }
        });
      }
    }
  }

  void _handleAnswer(int selectedIndex) {
    if (_answered) return; // Prevent changing answer

    setState(() {
      _answered = true;
      _selectedOptionIndex = selectedIndex;
      if (selectedIndex == widget.questions[_currentIndex].correctOptionIndex) {
        _score++;
      }
      _userAnswers[_currentIndex] = selectedIndex;
    });

    // Persist in-progress snapshot (exam mode only)
    if (widget.mode == QcmMode.exam) {
      _persistInProgress();
    }

    // In exam mode, auto-advance after a short delay; in study mode, stay on the question
    if (widget.mode == QcmMode.exam) {
      Future.delayed(const Duration(seconds: 2), () {
        _nextQuestion();
      });
    }
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedOptionIndex = null;
      });
      _refreshBookmarkState();
    } else {
      if (widget.mode == QcmMode.exam) {
        _finishExam();
      }
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _answered = false;
        _selectedOptionIndex = null;
      });
      _refreshBookmarkState();
    }
  }

  Future<void> _refreshBookmarkState() async {
    if (widget.mode != QcmMode.study) return;
    final q = widget.questions[_currentIndex];
    final id = _bookmarks.qidFor(q);
    final isBm = await _bookmarks.isBookmarked(id);
    final note = await _bookmarks.noteFor(id);
    if (!mounted) return;
    setState(() {
      _isBookmarked = isBm;
      _currentNote = note;
    });
  }

  Future<void> _toggleBookmarkForCurrent() async {
    final q = widget.questions[_currentIndex];
    await _bookmarks.toggleBookmark(q, note: _currentNote);
    await _refreshBookmarkState();
  }

  Future<void> _editNoteForCurrent() async {
    final q = widget.questions[_currentIndex];
    final id = _bookmarks.qidFor(q);
    final controller = TextEditingController(text: _currentNote ?? '');
    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Center(
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: GlassmorphicContainer(
              width: MediaQuery.of(ctx).size.width >= 700 ? 560 : double.infinity,
              height: MediaQuery.of(ctx).size.width >= 700
                  ? 420
                  : MediaQuery.of(ctx).size.height * 0.55,
              borderRadius: 20,
              blur: 18,
              border: 1.2,
              linearGradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.08),
                ],
              ),
              borderGradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.35),
                  Colors.white.withOpacity(0.15),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: StatefulBuilder(
                  builder: (ctx, setLocal) => Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.edit_note, color: Colors.cyanAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Note personnelle',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Fermer',
                              icon: const Icon(Icons.close, color: Colors.white70),
                              onPressed: () => Navigator.of(ctx).pop(null),
                            ),
                          ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Écrivez votre note ici…',
                            hintStyle: const TextStyle(color: Colors.white54),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.cyanAccent), borderRadius: BorderRadius.circular(12)),
                            fillColor: const Color(0x22222222),
                            filled: true,
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          onChanged: (_) => setLocal(() {}),
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final bool isNarrow = constraints.maxWidth < 500;
                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('${controller.text.trim().length} caractères',
                                    style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12)),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: controller.text.isEmpty
                                      ? null
                                      : () {
                                          controller.clear();
                                          setLocal(() {});
                                        },
                                  icon: const Icon(Icons.clear, size: 18, color: Colors.white),
                                  label: const Text('Effacer', style: TextStyle(color: Colors.white)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.white.withOpacity(0.5)),
                                    minimumSize: const Size.fromHeight(44),
                                  ),
                                ),
                                if ((_currentNote ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.of(ctx).pop(''),
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    label: const Text('Supprimer la note', style: TextStyle(color: Colors.redAccent)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.redAccent),
                                      minimumSize: const Size.fromHeight(44),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                                  icon: const Icon(Icons.save),
                                  label: const Text('Enregistrer'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyanAccent,
                                    foregroundColor: Colors.black,
                                    minimumSize: const Size.fromHeight(44),
                                  ),
                                ),
                              ],
                            );
                          }
                          // Wide layout
                          return Row(
                            children: [
                              Text('${controller.text.trim().length} caractères',
                                  style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12)),
                              const Spacer(),
                              OutlinedButton.icon(
                                onPressed: controller.text.isEmpty
                                    ? null
                                    : () {
                                        controller.clear();
                                        setLocal(() {});
                                      },
                                icon: const Icon(Icons.clear, size: 18, color: Colors.white),
                                label: const Text('Effacer', style: TextStyle(color: Colors.white)),
                                style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withOpacity(0.5))),
                              ),
                              const SizedBox(width: 8),
                              if ((_currentNote ?? '').isNotEmpty)
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.of(ctx).pop(''),
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  label: const Text('Supprimer la note', style: TextStyle(color: Colors.redAccent)),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                                ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                                icon: const Icon(Icons.save),
                                label: const Text('Enregistrer'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyanAccent,
                                  foregroundColor: Colors.black,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        );
      },
    );
    if (result != null) {
      final text = result.isEmpty ? null : result;
      await _bookmarks.updateNote(id, text);
      if (text != null) {
        await _bookmarks.toggleBookmark(q, note: text);
      }
      await _refreshBookmarkState();
    }
  }

  Future<void> _persistInProgress() async {
    // Only for exam mode
    if (widget.mode != QcmMode.exam) return;
    // Build record using live state, ensure remainingSeconds/currentIndex are current
    debugPrint('[QCM] Persist in-progress id=${_examId} rem=${_remainingSeconds}s idx=${_currentIndex} score=${_score}/${widget.questions.length}');
    final record = ExamRecord(
      id: _examId,
      date: DateTime.now(),
      durationMinutes: widget.examDurationMinutes ?? (widget.resumeRecord?.durationMinutes ?? 0),
      score: _score,
      total: widget.questions.length,
      categories: widget.selectedCategories ?? widget.questions.map((q) => q.category).toSet().toList(),
      questions: widget.questions,
      userAnswers: _userAnswers,
      completed: false,
      remainingSeconds: _remainingSeconds,
      currentIndex: _currentIndex,
    );
    await _storage.upsert(record);
  }

  Color _getOptionColor(int index) {
    // In exam mode, never reveal correctness. Only indicate selection subtly.
    if (widget.mode == QcmMode.exam) {
      final base = Colors.white.withOpacity(0.2);
      return index == _selectedOptionIndex ? Colors.cyan.withOpacity(0.35) : base;
    }
    if (!_answered) {
      return Colors.white.withOpacity(0.2);
    }
    if (index == widget.questions[_currentIndex].correctOptionIndex) {
      return Colors.green.withOpacity(0.7);
    }
    if (index == _selectedOptionIndex) {
      return Colors.red.withOpacity(0.7);
    }
    return Colors.white.withOpacity(0.2);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        body: const BackgroundContainer(
          child: Center(
            child: Text(
              'No questions available for this quiz.',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      );
    }

    final QcmQuestion currentQuestion = widget.questions[_currentIndex];

    return WillPopScope(
      onWillPop: () => _handleLeave(),
      child: Scaffold(
        body: BackgroundContainer(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // In-body header with title and progress (parity with Q/R)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () async {
                            final allow = await _handleLeave();
                            if (allow && mounted) {
                              final nav = Navigator.of(context);
                              nav.popUntil((r) => r.isFirst);
                              nav.push(MaterialPageRoute(builder: (_) => const CplScreen()));
                            }
                          },
                          tooltip: 'Fermer',
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                widget.mode == QcmMode.exam ? 'Exam' : 'QCM',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Question ${_currentIndex + 1} / ${widget.questions.length}',
                                style: GoogleFonts.montserrat(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (widget.mode == QcmMode.exam)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Text(
                              _formatTime(_remainingSeconds),
                              style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final double w = constraints.maxWidth;
                              final double v = (_currentIndex + 1) / widget.questions.length;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                width: w * v,
                                height: 8,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF50E3C2), Color(0xFF00BCD4)]),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Question Text
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.18),
                                      Colors.white.withOpacity(0.08),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white.withOpacity(0.28), width: 1.2),
                                ),
                                child: _buildQuestionContent(currentQuestion.question),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          // Options
                          ...List.generate(currentQuestion.options.length, (index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: GlassmorphicContainer(
                                width: double.infinity,
                                height: 65, // Provide a reasonable default height
                                borderRadius: 15,
                                blur: 10,
                                border: 1,
                                linearGradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFFffffff).withOpacity(0.2),
                                    const Color(0xFFFFFFFF).withOpacity(0.1),
                                  ],
                                ),
                                borderGradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFFffffff).withOpacity(0.5),
                                    const Color(0xFFFFFFFF).withOpacity(0.5),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _handleAnswer(index),
                                    borderRadius: BorderRadius.circular(15),
                                    child: Container(
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(15),
                                        color: _getOptionColor(index),
                                      ),
                                      child: Text(
                                        '${String.fromCharCode(65 + index)} - ${currentQuestion.options[index]}',
                                        style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (widget.mode == QcmMode.study && _answered) ...[
                            const SizedBox(height: 16),
                            _buildStudyFeedback(currentQuestion),
                          ],
                          if (widget.mode == QcmMode.study) ...[
                            const SizedBox(height: 4),
                            _buildStudyControls(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.mode == QcmMode.exam)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text('Soumettre l\'examen',
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                        onPressed: _confirmSubmit,
                      ),
                    ),
                  // Global bottom AdBanner is provided by BackgroundContainer
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionContent(String content) {
    if (content.contains('IMG:::')) {
      final parts = content.split('IMG:::');
      final textPart = parts[0].trim();
      final imagePath = parts[1].trim();

      return Column(
        mainAxisSize: MainAxisSize.min, // To keep the column height tight
        children: [
          if (textPart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                textPart,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          Image.asset(imagePath, fit: BoxFit.contain),
        ],
      );
    } else {
      return Text(
        content,
        textAlign: TextAlign.center,
        style: GoogleFonts.montserrat(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
      );
    }
  }

  Widget _buildStudyControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bookmarks/Notes row
          Row(
            children: [
              IconButton(
                tooltip: _isBookmarked ? 'Retirer des favoris' : 'Ajouter aux favoris',
                icon: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.cyanAccent,
                  size: 28,
                ),
                onPressed: () => _toggleBookmarkForCurrent(),
              ),
              IconButton(
                tooltip: 'Ajouter/éditer une note',
                icon: const Icon(Icons.edit_note, color: Colors.white, size: 30),
                onPressed: () => _editNoteForCurrent(),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                  );
                  // After returning, refresh state for current question
                  _refreshBookmarkState();
                },
                icon: const Icon(Icons.collections_bookmark, color: Colors.white),
                label: Text('Favoris', style: GoogleFonts.montserrat(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Reveal/Reset/Next controls row
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: _currentIndex > 0 ? _previousQuestion : null,
                tooltip: 'Précédent',
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: [
                    if (!_answered)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _answered = true; // reveal correctness coloring
                            });
                          },
                          icon: const Icon(Icons.visibility),
                          label: const Text('Afficher la réponse'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _answered = false;
                              _selectedOptionIndex = null;
                              _userAnswers[_currentIndex] = null;
                            });
                          },
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Réinitialiser', style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.6)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _currentIndex < widget.questions.length - 1 ? _nextQuestion : null,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Suivant'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudyFeedback(QcmQuestion q) {
    final ua = _selectedOptionIndex;
    final correct = q.correctOptionIndex;
    final bool isCorrect = ua != null && ua == correct;
    final Color badge = (isCorrect ? Colors.green : Colors.red).withOpacity(0.25);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badge,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCorrect ? 'Bonne réponse' : 'Mauvaise réponse',
                      style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Réponse correcte: ${String.fromCharCode(65 + correct)} - ${q.options[correct]}',
                      style: GoogleFonts.montserrat(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _finishExam() async {
    _timer?.cancel();
    _finished = true;
    debugPrint('[QCM] Finish exam id=${_examId} finalScore=${_score}/${widget.questions.length} rem=${_remainingSeconds}s');
    final record = ExamRecord(
      id: _examId,
      date: _examStartDate,
      durationMinutes: widget.examDurationMinutes ?? (widget.resumeRecord?.durationMinutes ?? 0),
      score: _score,
      total: widget.questions.length,
      categories: widget.selectedCategories ?? widget.questions.map((q) => q.category).toSet().toList(),
      questions: widget.questions,
      userAnswers: _userAnswers,
      completed: true,
      remainingSeconds: 0,
      currentIndex: _currentIndex,
    );
    await _storage.upsert(record);
    if (!mounted) return;
    // Try to show an interstitial before showing results
    await InterstitialAdService.loadIfNeeded();
    await InterstitialAdService.showIfAvailable();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => QcmResultsScreen(
          score: _score,
          totalQuestions: widget.questions.length,
          record: record,
        ),
      ),
    );
  }

  Future<bool> _handleLeave() async {
    if (widget.mode != QcmMode.exam) return Future.value(true);
    // Pause timer while dialog is shown to preserve remaining time
    final bool hadTimer = _timer != null;
    _timer?.cancel();
    // Ask user what to do when leaving exam (glass dialog)
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: GlassmorphicContainer(
            width: double.infinity,
            height: MediaQuery.of(ctx).size.height * 0.5,
            borderRadius: 24,
            blur: 20,
            alignment: Alignment.center,
            border: 1.2,
            linearGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.20),
                Colors.white.withOpacity(0.08),
              ],
            ),
            borderGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.6),
                Colors.white.withOpacity(0.2),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.6)),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.cyanAccent, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Quitter l\'examen ?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Soumettre maintenant, enregistrer et quitter, ou quitter sans enregistrer ?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(color: Colors.white70),
                  ),
                  if (widget.mode == QcmMode.exam) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.white70, size: 18),
                        const SizedBox(width: 6),
                        Text('Temps restant: ${_formatTime(_remainingSeconds)}',
                            style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop('submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Soumettre et enregistrer'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop('save_exit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(Icons.save),
                    label: const Text('Enregistrer et quitter'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop('leave'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.6)),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Quitter sans enregistrer'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(ctx).pop('cancel'),
                      icon: const Icon(Icons.close),
                      label: const Text('Annuler'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.6)),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (action == 'submit') {
      await _finishExam();
      return false; // navigation handled by results pushReplacement
    } else if (action == 'save_exit') {
      // Save in-progress snapshot and allow pop
      debugPrint('[QCM] Leave action: save_exit');
      await _persistInProgress();
      return true;
    } else if (action == 'leave') {
      // Do not persist; remove any in-progress snapshot for this session and allow pop
      debugPrint('[QCM] Leave action: leave without saving (delete snapshot, no persist)');
      _shouldAutoSave = false;
      try {
        await _storage.deleteById(_examId);
        debugPrint('[QCM] Deleted snapshot for id=${_examId}');
      } catch (e) {
        debugPrint('[QCM] Delete snapshot failed: $e');
      }
      return true;
    }
    // cancel -> resume timer if it was running
    if (hadTimer && _remainingSeconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds <= 0) {
            t.cancel();
            _finishExam();
          }
        });
        if (_remainingSeconds > 0) {
          _persistInProgress();
        }
      });
    }
    return false; // cancel
  }

  Future<void> _confirmSubmit() async {
    // Pause timer while confirm dialog is shown (exam mode)
    final bool hadTimer = _timer != null;
    _timer?.cancel();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: GlassmorphicContainer(
            width: double.infinity,
            height: MediaQuery.of(ctx).size.height * 0.5,
            borderRadius: 24,
            blur: 20,
            alignment: Alignment.center,
            border: 1.2,
            linearGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.20),
                Colors.white.withOpacity(0.08),
              ],
            ),
            borderGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.6),
                Colors.white.withOpacity(0.2),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.6)),
                      ),
                      child: const Icon(Icons.assignment_turned_in_outlined, color: Colors.cyanAccent, size: 30),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Soumettre l\'examen ?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vous ne pourrez plus modifier vos réponses.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(color: Colors.white70),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withOpacity(0.6)),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Soumettre'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (ok == true) {
      await _finishExam();
    } else if (hadTimer && _remainingSeconds > 0 && !_finished) {
      // Resume timer if user canceled
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds <= 0) {
            t.cancel();
            _finishExam();
          }
        });
        if (_remainingSeconds > 0) {
          _persistInProgress();
        }
      });
    }
  }
}

