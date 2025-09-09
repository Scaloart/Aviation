import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/models/exam_record.dart';
import 'package:brie_fly/services/exam_storage_service.dart';
import 'package:brie_fly/widgets/glass_confirm_dialog.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/screens/exam_review_screen.dart';
import 'package:brie_fly/screens/qcm_quiz_screen.dart';
import 'package:brie_fly/screens/qcm_category_screen.dart';
import 'package:brie_fly/models/qcm_question.dart';

class MyExamsScreen extends StatefulWidget {
  const MyExamsScreen({super.key});

  @override
  State<MyExamsScreen> createState() => _MyExamsScreenState();
}

class _MyExamsScreenState extends State<MyExamsScreen> {
  final ExamStorageService _storage = ExamStorageService();
  List<ExamRecord> _exams = const [];
  bool _loading = true;

  void _setExamsImmediate(List<ExamRecord> items) {
    setState(() {
      _exams = items;
      _loading = false;
    });
  }

  Future<void> _loadExams() async {
    final items = await _storage.getAll();
    if (!mounted) return;
    setState(() {
      _exams = items;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundContainer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text('Mes examens',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          )),
                    ),
                    IconButton(
                      tooltip: 'Supprimer tous',
                      icon: const Icon(Icons.delete_forever, color: Colors.white),
                      onPressed: () async {
                        final confirm = await showGlassConfirmDialog(
                          context,
                          title: 'Supprimer tous les examens',
                          message: 'Voulez-vous vraiment supprimer tous les examens ? Cette action est irréversible.',
                          confirmText: 'Supprimer tout',
                          cancelText: 'Annuler',
                          icon: Icons.delete_forever,
                          accentColor: const Color(0xFFE53935),
                        );
                        if (confirm == true) {
                          // Optimistic: update UI immediately
                          _setExamsImmediate(const []);
                          await _storage.clearAll();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Tous les examens ont été supprimés', style: GoogleFonts.montserrat()),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (_loading) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (_exams.isEmpty) {
                      return Center(
                        child: Text('Aucun examen enregistré',
                            style: GoogleFonts.montserrat(color: Colors.white70)),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: _exams.length,
                      itemBuilder: (context, index) {
                        final e = _exams[index];
                        final pct = e.total > 0 ? (e.score / e.total * 100).toStringAsFixed(0) : '0';
                        // Unfinished strictly means not completed
                        final bool unfinished = !e.completed;
                        final bool resumable = (unfinished && e.remainingSeconds > 0);
                        final int displayRemaining = resumable ? e.remainingSeconds : 0;
                        return Container
                          (
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.15)),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Examen ${index + 1}',
                                          style: GoogleFonts.montserrat(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          e.date.toLocal().toString().substring(0, 16),
                                          style: GoogleFonts.montserrat(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: unfinished ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      unfinished ? 'In progress' : 'Completed',
                                      style: GoogleFonts.montserrat(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _chip(Icons.timer, resumable ? _fmtTime(displayRemaining) : '${e.durationMinutes} min'),
                                  if (e.categories.isNotEmpty)
                                    _chip(Icons.label, e.categories.join(', '), maxWidth: 240),
                                  _chip(Icons.score, '${e.score}/${e.total} (${pct}%)'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final bool narrow = constraints.maxWidth < 420;

                                  Widget deleteBtn = SizedBox(
                                    width: 48,
                                    child: IconButton(
                                      tooltip: 'Supprimer cet examen',
                                      onPressed: () async {
                                        final confirm = await showGlassConfirmDialog(
                                          context,
                                          title: 'Supprimer cet examen',
                                          message: 'Confirmez la suppression de cet examen daté du\n${e.date.toLocal().toString().substring(0,16)}.',
                                          confirmText: 'Supprimer',
                                          cancelText: 'Annuler',
                                          icon: Icons.delete_outline,
                                          accentColor: const Color(0xFFE53935),
                                        );
                                        if (confirm == true) {
                                          final updated = List<ExamRecord>.from(_exams)..removeWhere((r) => r.id == e.id);
                                          _setExamsImmediate(updated);
                                          await _storage.deleteById(e.id);
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Examen supprimé', style: GoogleFonts.montserrat()),
                                              behavior: SnackBarBehavior.floating,
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.delete_outline, color: Colors.white70),
                                    ),
                                  );

                                  if (narrow) {
                                    // Stack buttons vertically to avoid overflow on small screens
                                    final List<Widget> buttons = [];
                                    if (resumable) {
                                      buttons.add(
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => QcmQuizScreen(
                                                  questions: e.questions,
                                                  mode: QcmMode.exam,
                                                  examDurationMinutes: e.durationMinutes,
                                                  selectedCategories: e.categories,
                                                  resumeRecord: e,
                                                ),
                                              ),
                                            );
                                            if (!mounted) return;
                                            await _loadExams();
                                          },
                                          icon: const Icon(Icons.play_arrow),
                                          label: Text('Continue (${_fmtTime(displayRemaining)})',
                                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.cyanAccent,
                                            foregroundColor: Colors.black,
                                            minimumSize: const Size.fromHeight(44),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      );
                                    } else if (unfinished) {
                                      buttons.add(
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => QcmQuizScreen(
                                                  questions: e.questions,
                                                  mode: QcmMode.exam,
                                                  examDurationMinutes: e.durationMinutes,
                                                  selectedCategories: e.categories,
                                                  resumeRecord: null,
                                                ),
                                              ),
                                            );
                                            if (!mounted) return;
                                            await _loadExams();
                                          },
                                          icon: const Icon(Icons.play_arrow),
                                          label: Text('Continue (${e.durationMinutes} min)',
                                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orangeAccent,
                                            foregroundColor: Colors.black,
                                            minimumSize: const Size.fromHeight(44),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      );
                                    } else {
                                      buttons.addAll([
                                        ElevatedButton.icon(
                                          onPressed: _hasMistakes(e) ? () => _startMistakesRetest(context, e) : null,
                                          icon: const Icon(Icons.replay),
                                          label: Text('Re-test erreurs',
                                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amberAccent,
                                            foregroundColor: Colors.black,
                                            minimumSize: const Size.fromHeight(44),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => ExamReviewScreen(record: e)),
                                            );
                                          },
                                          icon: const Icon(Icons.visibility, color: Colors.white),
                                          label: Text('Review',
                                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.white)),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: Colors.white.withOpacity(0.6)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            minimumSize: const Size.fromHeight(44),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ]);
                                    }

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        ...buttons,
                                        const SizedBox(height: 8),
                                        Align(alignment: Alignment.centerRight, child: deleteBtn),
                                      ],
                                    );
                                  }

                                  // Wide layout: keep buttons in a row
                                  return Row(
                                    children: [
                                      if (resumable)
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => QcmQuizScreen(
                                                    questions: e.questions,
                                                    mode: QcmMode.exam,
                                                    examDurationMinutes: e.durationMinutes,
                                                    selectedCategories: e.categories,
                                                    // Resume session with remaining time
                                                    resumeRecord: e,
                                                  ),
                                                ),
                                              );
                                              if (!mounted) return;
                                              await _loadExams();
                                            },
                                            icon: const Icon(Icons.play_arrow),
                                            label: Text('Continue (${_fmtTime(displayRemaining)})',
                                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.cyanAccent,
                                              foregroundColor: Colors.black,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                        )
                                      else if (unfinished)
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => QcmQuizScreen(
                                                    questions: e.questions,
                                                    mode: QcmMode.exam,
                                                    examDurationMinutes: e.durationMinutes,
                                                    selectedCategories: e.categories,
                                                    // Restart fresh if no time saved
                                                    resumeRecord: null,
                                                  ),
                                                ),
                                              );
                                              if (!mounted) return;
                                              await _loadExams();
                                            },
                                            icon: const Icon(Icons.play_arrow),
                                            label: Text('Continue (${e.durationMinutes} min)',
                                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orangeAccent,
                                              foregroundColor: Colors.black,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                        )
                                      else ...[
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _hasMistakes(e) ? () => _startMistakesRetest(context, e) : null,
                                            icon: const Icon(Icons.replay),
                                            label: Text('Re-test erreurs',
                                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.amberAccent,
                                              foregroundColor: Colors.black,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => ExamReviewScreen(record: e)),
                                              );
                                            },
                                            icon: const Icon(Icons.visibility, color: Colors.white),
                                            label: Text('Review',
                                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.white)),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: Colors.white.withOpacity(0.6)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 10),
                                      deleteBtn,
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text, {double? maxWidth}) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(color: Colors.white70),
          ),
        ),
      ],
    );
    return Container(
      constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth) : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: child,
    );
  }

  String _fmtTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool _hasMistakes(ExamRecord e) {
    for (int i = 0; i < e.questions.length; i++) {
      final ua = e.userAnswers[i];
      if (ua == null || ua != e.questions[i].correctOptionIndex) return true;
    }
    return false;
  }

  void _startMistakesRetest(BuildContext context, ExamRecord e) {
    final List<QcmQuestion> wrong = [];
    final Set<String> cats = {};
    for (int i = 0; i < e.questions.length; i++) {
      final ua = e.userAnswers[i];
      final q = e.questions[i];
      if (ua == null || ua != q.correctOptionIndex) {
        wrong.add(q);
        cats.add(q.category);
      }
    }
    if (wrong.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune erreur à ré-essayer')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QcmQuizScreen(
          questions: wrong,
          mode: QcmMode.exam,
          examDurationMinutes: e.durationMinutes,
          selectedCategories: cats.toList(),
        ),
      ),
    );
  }
}

