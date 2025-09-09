import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/models/exam_record.dart';
import 'package:brie_fly/screens/exam_review_screen.dart';
import 'package:brie_fly/screens/my_exams_screen.dart';
import 'package:brie_fly/screens/qcm_category_screen.dart';
import 'package:brie_fly/screens/qcm_quiz_screen.dart';
import 'package:brie_fly/models/qcm_question.dart';

class QcmResultsScreen extends StatelessWidget {
  final int score;
  final int totalQuestions;
  final ExamRecord? record; // optional: allow review if provided

  const QcmResultsScreen({super.key, required this.score, required this.totalQuestions, this.record});

  @override
  Widget build(BuildContext context) {
    final double percentage = totalQuestions > 0 ? (score / totalQuestions) * 100 : 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: BackgroundContainer(
        child: SafeArea(
          child: Stack(
            children: [
              // Close button
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Back to QCM',
                  onPressed: () {
                    // Go back to app root (CPL), then open QCM so its back returns to CPL
                    final nav = Navigator.of(context);
                    nav.popUntil((route) => route.isFirst);
                    nav.push(
                      MaterialPageRoute(builder: (_) => const QcmCategoryScreen()),
                    );
                  },
                ),
              ),
              // Centered content
              Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                      child: GlassmorphicContainer(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.7,
                        borderRadius: 20,
                        blur: 14,
                        border: 1.2,
                        alignment: Alignment.center,
                        linearGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.16),
                            Colors.white.withOpacity(0.06),
                          ],
                        ),
                        borderGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.45),
                            Colors.white.withOpacity(0.25),
                          ],
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Your Score',
                                style: GoogleFonts.montserrat(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 24),
                              // Large, styled percentage and score (no ring)
                              ShaderMask(
                                shaderCallback: (Rect bounds) {
                                  return const LinearGradient(
                                    colors: [Color(0xFF50E3C2), Color(0xFF00BCD4)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(bounds);
                                },
                                blendMode: BlendMode.srcIn,
                                child: Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 88,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '$score / $totalQuestions',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  fontSize: 24,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Stat chips
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: [
                                  _statChip(Icons.check_circle, '${score}', 'Correct', Colors.greenAccent),
                                  _statChip(Icons.cancel, '${totalQuestions - score}', 'Incorrect', Colors.redAccent),
                                  if (record != null)
                                    _statChip(Icons.timer, '${record!.durationMinutes} min', 'Duration', Colors.cyanAccent),
                                  if (record != null)
                                    _statChip(Icons.event, _formatDate(record!.date), 'Date', Colors.purpleAccent),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Actions (responsive)
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final bool isNarrow = constraints.maxWidth < 600;
                                  if (isNarrow) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.cyanAccent,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            minimumSize: const Size.fromHeight(44),
                                          ),
                                          onPressed: () {
                                            final nav = Navigator.of(context);
                                            nav.popUntil((route) => route.isFirst);
                                            nav.push(
                                              MaterialPageRoute(builder: (_) => const QcmCategoryScreen()),
                                            );
                                          },
                                          child: Text('Try Again', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                                        ),
                                        if (record != null) ...[
                                          const SizedBox(height: 10),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.amberAccent,
                                              foregroundColor: Colors.black,
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              minimumSize: const Size.fromHeight(44),
                                            ),
                                            onPressed: () => _startMistakesRetest(context),
                                            child: Text('Re-test mistakes', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                                          ),
                                          const SizedBox(height: 10),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: Colors.black,
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              minimumSize: const Size.fromHeight(44),
                                            ),
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => ExamReviewScreen(record: record!)),
                                              );
                                            },
                                            child: Text('Review this exam', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                                          ),
                                        ],
                                      ],
                                    );
                                  }
                                  // Wide layout
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.cyanAccent,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () {
                                            final nav = Navigator.of(context);
                                            nav.popUntil((route) => route.isFirst);
                                            nav.push(
                                              MaterialPageRoute(builder: (_) => const QcmCategoryScreen()),
                                            );
                                          },
                                          child: Text('Try Again', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (record != null)
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.amberAccent,
                                              foregroundColor: Colors.black,
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () => _startMistakesRetest(context),
                                            child: Text('Re-test mistakes', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                                          ),
                                        ),
                                      const SizedBox(width: 12),
                                      if (record != null)
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: Colors.black,
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => ExamReviewScreen(record: record!)),
                                              );
                                            },
                                            child: Text('Review this exam', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              if (record != null) ...[
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const MyExamsScreen()),
                                    );
                                  },
                                  child: Text('Go to My Exams', style: GoogleFonts.montserrat(color: Colors.white70)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Small helper to render stat chips consistently
  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(value, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.montserrat(color: Colors.white70)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Simple human-readable date, e.g., 2025-08-25 12:34
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}  ${two(date.hour)}:${two(date.minute)}';
  }

  void _startMistakesRetest(BuildContext context) {
    final rec = record;
    if (rec == null) return;
    final List<QcmQuestion> wrong = [];
    final Set<String> cats = {};
    for (int i = 0; i < rec.questions.length; i++) {
      final ua = rec.userAnswers[i];
      final q = rec.questions[i];
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
          examDurationMinutes: rec.durationMinutes,
          selectedCategories: cats.toList(),
        ),
      ),
    );
  }
}

