import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/services/bookmarks_service.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/models/question.dart';
import 'package:brie_fly/services/ads/interstitial_ad_service.dart';

class _RevealIntent extends Intent {
  const _RevealIntent();
}

class _PrevIntent extends Intent {
  const _PrevIntent();
}

class _RightIntent extends Intent {
  const _RightIntent();
}

class QuizScreen extends StatefulWidget {
  final List<Question> questions;

  const QuizScreen({super.key, required this.questions});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _score = 0;
  bool _showAnswer = false;
  late List<bool?> _userAnswers;
  final BookmarksService _bookmarks = BookmarksService();
  bool _bookmarked = false;
  String? _currentNote;

  late AnimationController _cardAnimationController;
  late Animation<Offset> _slideAnimation;

  // Keyboard intents are defined as Intent classes above; no fields needed here

  @override
  void initState() {
    super.initState();
    _userAnswers = List<bool?>.filled(widget.questions.length, null);
    _cardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardAnimationController, curve: Curves.easeOut));

    _cardAnimationController.forward();
    _refreshBookmarkState();
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    super.dispose();
  }

  void _nextQuestion({required bool knewAnswer}) {
    // Only score the question the first time it's answered
    if (_userAnswers[_currentIndex] == null) {
      _userAnswers[_currentIndex] = knewAnswer;
      if (knewAnswer) {
        _score++;
      }
    }

    if (_currentIndex < widget.questions.length - 1) {
      _cardAnimationController.reverse().then((_) {
        setState(() {
          _currentIndex++;
          _showAnswer = false;
          _cardAnimationController.forward();
        });
        _refreshBookmarkState();
      });
    } else {
      _showFinalScore();
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      _cardAnimationController.reverse().then((_) {
        setState(() {
          // When going back, we always show the answer for review
          _showAnswer = true;
          _currentIndex--;
          _cardAnimationController.forward();
        });
        _refreshBookmarkState();
      });
    }
  }

  Future<void> _refreshBookmarkState() async {
    final q = widget.questions[_currentIndex];
    final id = BookmarksService().qidForQr(q);
    final marked = await _bookmarks.isBookmarked(id);
    final note = await _bookmarks.noteFor(id);
    if (!mounted) return;
    setState(() {
      _bookmarked = marked;
      _currentNote = note;
    });
  }

  Future<void> _toggleBookmark() async {
    final q = widget.questions[_currentIndex];
    await _bookmarks.toggleBookmarkQr(q, note: _currentNote);
    await _refreshBookmarkState();
  }

  Future<void> _editNoteForCurrent() async {
    final q = widget.questions[_currentIndex];
    final id = BookmarksService().qidForQr(q);
    final controller = TextEditingController(text: _currentNote ?? '');
    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: double.infinity,
                height: MediaQuery.of(ctx).size.height * 0.55,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.white.withOpacity(0.08),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.24)),
                ),
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
                              child: Text('Note personnelle',
                                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
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
                              hintText: 'Écrivez votre note ici... (facultatif)',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.25),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                            onChanged: (_) => setLocal(() {}),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${controller.text.length}/1000',
                                style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Effacer',
                              onPressed: () {
                                controller.clear();
                                setLocal(() {});
                              },
                              icon: const Icon(Icons.clear, color: Colors.white70),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(''),
                              child: Text('Supprimer la note', style: GoogleFonts.montserrat(color: Colors.redAccent)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent.withOpacity(0.9)),
                              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                              icon: const Icon(Icons.save, color: Colors.black87),
                              label: Text('Enregistrer', style: GoogleFonts.montserrat(color: Colors.black87, fontWeight: FontWeight.w700)),
                            )
                          ],
                        )
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

    if (result == null) return; // dismissed
    final trimmed = result.isEmpty ? null : result;
    await _bookmarks.updateNote(id, trimmed);
    // Ensure it's bookmarked if a note exists, or remove if no note and not manually bookmarked
    await _bookmarks.toggleBookmarkQr(q, note: trimmed);
    await _refreshBookmarkState();
  }

  void _showFinalScore() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2B3A).withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Quiz Complete!',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Your final score is: $_score / ${widget.questions.length}',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Try to show an interstitial before closing the session
              await InterstitialAdService.loadIfNeeded();
              await InterstitialAdService.showIfAvailable();
              Navigator.of(context).pop(); // Close the dialog
              Navigator.of(context).pop(); // Go back to category selection
            },
            child: Text(
              'OK',
              style: GoogleFonts.montserrat(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.questions[_currentIndex];
    final progress = (_currentIndex + 1) / widget.questions.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackgroundContainer(
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.space): _RevealIntent(),
              SingleActivator(LogicalKeyboardKey.arrowLeft): _PrevIntent(),
              SingleActivator(LogicalKeyboardKey.arrowRight): _RightIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                _RevealIntent: CallbackAction<_RevealIntent>(onInvoke: (intent) {
                  setState(() => _showAnswer = true);
                  return null;
                }),
                _PrevIntent: CallbackAction<_PrevIntent>(onInvoke: (intent) {
                  _previousQuestion();
                  return null;
                }),
                _RightIntent: CallbackAction<_RightIntent>(onInvoke: (intent) {
                  if (!_showAnswer) setState(() => _showAnswer = true);
                  return null;
                }),
              },
              child: Focus(
                autofocus: true,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Glass header bar under the AppWindowBar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.16),
                                  Colors.white.withOpacity(0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.24)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      onPressed: () => Navigator.of(context).pop(),
                                      tooltip: 'Fermer',
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${_currentIndex + 1} / ${widget.questions.length}',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    if (_currentIndex > 0)
                                      IconButton(
                                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                                        onPressed: _previousQuestion,
                                        tooltip: 'Question précédente',
                                      )
                                    else
                                      const SizedBox(width: 48),
                                    const SizedBox(width: 4),
                                    Tooltip(
                                      message: _bookmarked ? 'Retirer des favoris' : 'Ajouter aux favoris',
                                      child: IconButton(
                                        icon: Icon(_bookmarked ? Icons.bookmark : Icons.bookmark_add_outlined, color: Colors.cyanAccent),
                                        onPressed: _toggleBookmark,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Tooltip(
                                      message: 'Note personnelle',
                                      child: IconButton(
                                        icon: const Icon(Icons.edit_note, color: Colors.white),
                                        onPressed: _editNoteForCurrent,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    minHeight: 6,
                                    value: progress,
                                    backgroundColor: Colors.white.withOpacity(0.18),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildScoreBar(),
                      Expanded(
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildQuestionCard(currentQuestion),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAnswerControls(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question question) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.label, size: 16, color: Colors.cyanAccent),
                                const SizedBox(width: 6),
                                Text(
                                  question.category,
                                  style: GoogleFonts.montserrat(
                                    color: Colors.cyanAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        question.question,
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                        child: _showAnswer
                            ? Padding(
                                key: ValueKey<int>(_currentIndex),
                                padding: const EdgeInsets.only(top: 24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(color: Colors.white54),
                                    _buildAnswerWidget(question.answer),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              // Floating navigation arrows
              if (_currentIndex > 0)
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _GlassCircleIconButton(
                      icon: Icons.chevron_left,
                      onTap: _previousQuestion,
                      tooltip: 'Précédente',
                    ),
                  ),
                ),
              if (!_showAnswer)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _GlassCircleIconButton(
                      icon: Icons.visibility,
                      onTap: () => setState(() => _showAnswer = true),
                      tooltip: 'Afficher',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerControls() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _showAnswer
          ? Row(
              key: const ValueKey('answer_buttons'),
              children: [
                Expanded(
                  child: _GlassButton(
                    text: 'Je savais',
                    icon: Icons.check_circle,
                    gradientColors: const [Color(0xFF00C853), Color(0xFF00E676)],
                    onTap: () => _nextQuestion(knewAnswer: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _GlassButton(
                    text: 'Pas encore',
                    icon: Icons.close_rounded,
                    gradientColors: const [Color(0xFFD32F2F), Color(0xFFFF5252)],
                    onTap: () => _nextQuestion(knewAnswer: false),
                  ),
                ),
              ],
            )
          : _GlassButton(
              key: const ValueKey('show_button'),
              text: 'Afficher la réponse',
              icon: Icons.visibility,
              gradientColors: const [Color(0xFF00ACC1), Color(0xFF26C6DA)],
              onTap: () => setState(() => _showAnswer = true),
              expanded: true,
            ),
    );
  }

  Widget _buildFeedbackButton({required String text, required Color color, required VoidCallback onPressed}) {
    // Kept for compatibility; not used after polish but retained to avoid breaking references
    return _GlassButton(text: text, icon: Icons.check, gradientColors: [color, color.withOpacity(0.85)], onTap: onPressed);
  }

  Widget _buildAnswerWidget(String answer) {
    final regex = RegExp(r'IMG:::(\S+)');
    final matches = regex.allMatches(answer).toList();
    final firstMatch = matches.isNotEmpty ? matches.first : null;
    final textBefore = firstMatch == null ? answer.trim() : answer.substring(0, firstMatch.start).trim();

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (textBefore.isNotEmpty)
            Text(
              textBefore,
              textAlign: TextAlign.left,
              style: GoogleFonts.lato(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                height: 1.5,
              ),
            ),
          for (final m in matches)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  m.group(1)!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreBar() {
    final int correctCount = _userAnswers.where((a) => a == true).length;
    final int incorrectCount = _userAnswers.where((a) => a == false).length;
    final int answeredCount = correctCount + incorrectCount;
    final double percentage = answeredCount == 0 ? 0 : (correctCount / answeredCount) * 100;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.trending_up, size: 18, color: Colors.cyanAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double totalWidth = constraints.maxWidth;
                        final double correctWidth = answeredCount == 0 ? 0.0 : totalWidth * (correctCount / answeredCount);
                        final double incorrectWidth = answeredCount == 0 ? 0.0 : totalWidth * (incorrectCount / answeredCount);
                        return Stack(children: [
                          Container(
                            width: correctWidth,
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF00E676)]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          Positioned(
                            left: correctWidth,
                            child: Container(
                              width: incorrectWidth,
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFFF5252)]),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ]);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final bool expanded;

  const _GlassButton({Key? key, required this.text, required this.icon, required this.gradientColors, required this.onTap, this.expanded = false}) : super(key: key);

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      transform: Matrix4.identity()..scale(_pressed ? 0.98 : (_hover ? 1.01 : 1.0)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.24)),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: widget.gradientColors.last.withOpacity(0.35),
                        blurRadius: 18,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
              gradient: LinearGradient(
                colors: [
                  widget.gradientColors.first.withOpacity(0.25),
                  widget.gradientColors.last.withOpacity(0.18),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  widget.text,
                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final button = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: content,
      ),
    );

    if (widget.expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class _GlassCircleIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _GlassCircleIconButton({required this.icon, required this.onTap, this.tooltip});

  @override
  State<_GlassCircleIconButton> createState() => _GlassCircleIconButtonState();
}

class _GlassCircleIconButtonState extends State<_GlassCircleIconButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final circle = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.identity()..scale(_pressed ? 0.96 : (_hover ? 1.05 : 1.0)),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      )
                    ]
                  : null,
            ),
            child: Icon(widget.icon, color: Colors.white),
          ),
        ),
      ),
    );

    final body = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: circle,
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: body);
    }
    return body;
  }
}

