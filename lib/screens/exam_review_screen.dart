import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/models/exam_record.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/screens/qcm_quiz_screen.dart';
import 'package:brie_fly/models/qcm_question.dart';
import 'package:brie_fly/screens/qcm_category_screen.dart';

class ExamReviewScreen extends StatefulWidget {
  final ExamRecord record;
  const ExamReviewScreen({super.key, required this.record});

  @override
  State<ExamReviewScreen> createState() => _ExamReviewScreenState();
}

class _ExamReviewScreenState extends State<ExamReviewScreen> {
  bool _onlyIncorrect = false;

  int get _correctCount {
    int c = 0;
    for (int i = 0; i < widget.record.questions.length; i++) {
      if (widget.record.userAnswers[i] == widget.record.questions[i].correctOptionIndex) c++;
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.record.total;
    final wrongIndices = List<int>.generate(total, (i) => i)
        .where((i) => widget.record.userAnswers[i] != widget.record.questions[i].correctOptionIndex)
        .toList();
    final indices = _onlyIncorrect ? wrongIndices : List<int>.generate(total, (i) => i);

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
                      child: Text('Révision de l\'examen',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          )),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Header summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
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
                                  'Examen',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.record.date.toLocal().toString().substring(0, 16),
                                  style: GoogleFonts.montserrat(color: Colors.white70, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_correctCount}/${total}  (${(_correctCount / (total == 0 ? 1 : total) * 100).toStringAsFixed(0)}%)',
                              style: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _chip(Icons.timer, '${widget.record.durationMinutes} min'),
                          if (widget.record.categories.isNotEmpty)
                            _chip(Icons.label, widget.record.categories.join(', ')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final bool narrow = constraints.maxWidth < 480;
                          final statsText = _onlyIncorrect
                              ? Text('${wrongIndices.length} erreurs', style: GoogleFonts.montserrat(color: Colors.white70))
                              : const SizedBox.shrink();

                          final retryBtn = ElevatedButton.icon(
                            onPressed: wrongIndices.isEmpty ? null : () => _startMistakesRetest(context),
                            icon: const Icon(Icons.replay),
                            label: Text('Re-test erreurs', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              minimumSize: narrow ? const Size.fromHeight(44) : null,
                            ),
                          );

                          if (narrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FilterChip(
                                    label: Text('Afficher uniquement les erreurs', style: GoogleFonts.montserrat()),
                                    selected: _onlyIncorrect,
                                    onSelected: (v) => setState(() => _onlyIncorrect = v),
                                    selectedColor: Colors.redAccent.withOpacity(0.25),
                                    backgroundColor: Colors.white.withOpacity(0.08),
                                    checkmarkColor: Colors.white,
                                  ),
                                ),
                                if (_onlyIncorrect) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '${wrongIndices.length} erreurs',
                                    style: GoogleFonts.montserrat(color: Colors.white70),
                                    softWrap: true,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                retryBtn,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              FilterChip(
                                label: Text('Afficher uniquement les erreurs', style: GoogleFonts.montserrat()),
                                selected: _onlyIncorrect,
                                onSelected: (v) => setState(() => _onlyIncorrect = v),
                                selectedColor: Colors.redAccent.withOpacity(0.25),
                                backgroundColor: Colors.white.withOpacity(0.08),
                                checkmarkColor: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              if (_onlyIncorrect) Flexible(child: statsText),
                              const Spacer(),
                              retryBtn,
                            ],
                          );
                        },
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: indices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, listIdx) {
                    final i = indices[listIdx];
                    final q = widget.record.questions[i];
                    final ua = widget.record.userAnswers[i];
                    final correct = q.correctOptionIndex;
                    final isCorrect = ua == correct;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final bool narrow = constraints.maxWidth < 420;
                              final status = Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (isCorrect ? Colors.green : Colors.red).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(isCorrect ? Icons.check_circle : Icons.cancel, size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      isCorrect ? 'Correct' : 'Incorrect',
                                      style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                                    ),
                                  ],
                                ),
                              );

                              if (narrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Q${i + 1}. ${q.question}',
                                      style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(alignment: Alignment.centerRight, child: status),
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Q${i + 1}. ${q.question}',
                                      style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                  ),
                                  status,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          ...List.generate(q.options.length, (idx) {
                            final option = q.options[idx];
                            final optionIsCorrect = idx == correct;
                            final optionIsUser = ua == idx;
                            Color bg;
                            Color border;
                            IconData? leading;
                            if (optionIsCorrect) {
                              bg = Colors.green.withOpacity(0.35);
                              border = Colors.greenAccent.withOpacity(0.6);
                              leading = Icons.check_circle_outline;
                            } else if (optionIsUser && !optionIsCorrect) {
                              bg = Colors.red.withOpacity(0.35);
                              border = Colors.redAccent.withOpacity(0.6);
                              leading = Icons.highlight_off;
                            } else {
                              bg = Colors.white.withOpacity(0.06);
                              border = Colors.white.withOpacity(0.18);
                              leading = Icons.radio_button_unchecked;
                            }
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: border),
                              ),
                              child: Row(
                                children: [
                                  Icon(leading, size: 18, color: Colors.white70),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${String.fromCharCode(65 + idx)} - $option',
                                      style: GoogleFonts.montserrat(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final bool narrow = constraints.maxWidth < 420;
                              final yourAnswer = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person, size: 16, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Text('Votre réponse: ', style: GoogleFonts.montserrat(color: Colors.white70)),
                                  Text(ua == null ? '-' : String.fromCharCode(65 + ua),
                                      style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700)),
                                ],
                              );
                              final correctAnswer = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check, size: 16, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Text('Réponse correcte: ', style: GoogleFonts.montserrat(color: Colors.white70)),
                                  Text(String.fromCharCode(65 + correct),
                                      style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700)),
                                ],
                              );

                              if (narrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    yourAnswer,
                                    const SizedBox(height: 6),
                                    correctAnswer,
                                  ],
                                );
                              }

                              return Wrap(
                                spacing: 16,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [yourAnswer, correctAnswer],
                              );
                            },
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
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
            ),
          ),
        );
      },
    );
  }

  void _startMistakesRetest(BuildContext context) {
    final ExamRecord rec = widget.record;
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

