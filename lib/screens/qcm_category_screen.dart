import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/models/qcm_question.dart';
import 'package:brie_fly/screens/qcm_quiz_screen.dart';
import 'package:brie_fly/screens/my_exams_screen.dart';
import 'package:brie_fly/screens/cpl_screen.dart';
import 'package:brie_fly/services/qcm_question_service.dart';
import 'package:brie_fly/screens/bookmarks_screen.dart';
import 'package:brie_fly/services/ads/interstitial_ad_service.dart';

// Secondary glass title/actions bar (adapted from Q/R)
class _SecondaryTitleBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClear;
  const _SecondaryTitleBar({required this.title, required this.subtitle, this.onSelectAll, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.14),
                  Colors.white.withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isNarrow = constraints.maxWidth < 600;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      if (onSelectAll != null || onClear != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (onSelectAll != null)
                              TextButton(
                                onPressed: onSelectAll,
                                style: TextButton.styleFrom(foregroundColor: Colors.white),
                                child: const Text('Tout sélectionner'),
                              ),
                            if (onClear != null)
                              TextButton(
                                onPressed: onClear,
                                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                                child: const Text('Effacer'),
                              ),
                          ],
                        ),
                      ],
                    ],
                  );
                }
                // Wide layout
                return Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.montserrat(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (onSelectAll != null)
                      TextButton(
                        onPressed: onSelectAll,
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        child: const Text('Tout sélectionner'),
                      ),
                    if (onClear != null)
                      TextButton(
                        onPressed: onClear,
                        style: TextButton.styleFrom(foregroundColor: Colors.white70),
                        child: const Text('Effacer'),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

}

enum QcmMode { exam, study }

class QcmCategoryScreen extends StatefulWidget {
  const QcmCategoryScreen({super.key});

  @override
  State<QcmCategoryScreen> createState() => _QcmCategoryScreenState();
}

class _QcmCategoryScreenState extends State<QcmCategoryScreen> {
  late Future<Map<String, List<QcmQuestion>>> _questionsFuture;
  final QcmQuestionService _questionService = QcmQuestionService();
  final Set<String> _selectedCategories = {};
  double _numberOfQuestions = 10;
  int _maxQuestions = 10;
  QcmMode _selectedMode = QcmMode.study;
  final List<int> _examDurations = const [10, 20, 30, 45, 60];
  int _selectedExamDuration = 30;

  @override
  void initState() {
    super.initState();
    _questionsFuture = _questionService.loadQuestions();
  }

  void _updateMaxQuestions() {
    int total = 0;
    _questionsFuture.then((data) {
      if (!mounted) return;
      for (var category in _selectedCategories) {
        total += data[category]?.length ?? 0;
      }
      setState(() {
        _maxQuestions = total > 0 ? total : 1; 
        if (_maxQuestions > 0 && _numberOfQuestions < 1) {
          _numberOfQuestions = 1.0;
        }
        if (_numberOfQuestions > _maxQuestions) {
          _numberOfQuestions = _maxQuestions.toDouble();
        }
      });
    });
  }

  Widget _buildExamDurationSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Text('Durée d\'examen',
                    style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.9)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedExamDuration,
                      isDense: true,
                      dropdownColor: Colors.black87,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.cyanAccent),
                      style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700),
                      items: _examDurations
                          .map((d) => DropdownMenuItem<int>(
                                value: d,
                                child: Text(
                                  '$d min',
                                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedExamDuration = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundContainer(
        child: SafeArea(
          child: FutureBuilder<Map<String, List<QcmQuestion>>>(
            future: _questionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No questions found.', style: TextStyle(color: Colors.white)));
              } else {
                return _buildContent(snapshot.data!);
              }
            },
          ),
        ),
      ),
    );
  }

  

  Widget _buildContent(Map<String, List<QcmQuestion>> categoryData) {
    final categories = categoryData.keys.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateMaxQuestions();
    });

    return SingleChildScrollView(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
          // In-body header (like Q/R)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isNarrow = constraints.maxWidth < 600;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () {
                              final nav = Navigator.of(context);
                              nav.popUntil((route) => route.isFirst);
                              nav.push(MaterialPageRoute(builder: (_) => const CplScreen()));
                            },
                            tooltip: 'Retour',
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 4,
                            children: <Widget>[
                              IconButton(
                                icon: const Icon(Icons.history, color: Colors.white),
                                tooltip: 'Mes examens',
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const MyExamsScreen()),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.bookmark, color: Colors.white),
                                tooltip: 'Favoris',
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        'QCM',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Questions à choix multiples',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  );
                }
                // Wide layout
                return Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        final nav = Navigator.of(context);
                        nav.popUntil((route) => route.isFirst);
                        nav.push(MaterialPageRoute(builder: (_) => const CplScreen()));
                      },
                      tooltip: 'Retour',
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            'QCM',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Questions à choix multiples',
                            style: GoogleFonts.montserrat(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.history, color: Colors.white),
                          tooltip: 'Mes examens',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const MyExamsScreen()),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.bookmark, color: Colors.white),
                          tooltip: 'Favoris',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          // Secondary title/actions bar (Tout sélectionner / Effacer)
          _SecondaryTitleBar(
            title: 'Questions à choix multiples (QCM)',
            subtitle: 'Choisissez vos catégories et lancez une session',
            onSelectAll: categories.isNotEmpty && _selectedCategories.length != categories.length
                ? () => setState(() {
                      _selectedCategories
                        ..clear()
                        ..addAll(categories);
                      _updateMaxQuestions();
                    })
                : null,
            onClear: _selectedCategories.isNotEmpty
                ? () => setState(() {
                      _selectedCategories.clear();
                      _updateMaxQuestions();
                    })
                : null,
          ),
          const SizedBox(height: 8),
          // Centered section title before grid
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              'Sélectionnez des catégories',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          // Categories grid (non-scrollable, page scrolls)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                final int columns = width >= 1100
                    ? 4
                    : width >= 820
                        ? 3
                        : width >= 560
                            ? 2
                            : 1;
                final double aspect = columns == 1
                    ? 3.0
                    : columns == 2
                        ? 2.8
                        : 2.6;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: aspect,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final bool isSelected = _selectedCategories.contains(category);
                    final int count = categoryData[category]?.length ?? 0;
                    return _buildCategoryTile(
                      title: category,
                      count: count,
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedCategories.remove(category);
                          } else {
                            _selectedCategories.add(category);
                          }
                        });
                        _updateMaxQuestions();
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (_selectedCategories.isNotEmpty) ...<Widget>[
            if (_selectedMode == QcmMode.study) _buildQuestionSlider(),
            if (_selectedMode == QcmMode.exam) _buildExamDurationSelector(),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: <Widget>[
                  _buildModeSelector(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await InterstitialAdService.loadIfNeeded();
                        await InterstitialAdService.showIfAvailable();
                        _startQuiz();
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 26),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Text(
                          'Commencer',
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.5),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryTile({required String title, required int count, required bool selected, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withOpacity(0.2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(selected ? 0.28 : 0.18),
                  Colors.white.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(selected ? 0.45 : 0.25)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.list_alt, size: 16, color: Colors.cyanAccent),
                      const SizedBox(width: 6),
                      Text('$count', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: selected
                      ? const Icon(Icons.check_circle, key: ValueKey('sel'), color: Colors.cyanAccent)
                      : const SizedBox(width: 24, key: ValueKey('unsel')),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withOpacity(0.25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(label, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Nombre de questions',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF50E3C2).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF50E3C2).withOpacity(0.9)),
                      ),
                      child: Text(
                        _numberOfQuestions.round().toString(),
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.remove,
                      onTap: _maxQuestions > 0 && _numberOfQuestions > 1
                          ? () => setState(() => _numberOfQuestions = (_numberOfQuestions - 1).clamp(1, _maxQuestions).toDouble())
                          : null,
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: const Color(0xFF50E3C2),
                          inactiveTrackColor: Colors.white.withOpacity(0.25),
                          thumbColor: Colors.cyanAccent,
                          overlayColor: Colors.cyanAccent.withOpacity(0.15),
                          valueIndicatorColor: Colors.cyanAccent,
                          valueIndicatorTextStyle: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.w700),
                        ),
                        child: Slider(
                          value: _numberOfQuestions,
                          min: _maxQuestions > 0 ? 1.0 : 0.0,
                          max: _maxQuestions.toDouble(),
                          divisions: _maxQuestions > 1 ? _maxQuestions - 1 : 1,
                          label: _numberOfQuestions.round().toString(),
                          onChanged: (double value) {
                            setState(() {
                              _numberOfQuestions = value;
                            });
                          },
                        ),
                      ),
                    ),
                    _RoundIconButton(
                      icon: Icons.add,
                      onTap: _maxQuestions > 0 && _numberOfQuestions < _maxQuestions
                          ? () => setState(() => _numberOfQuestions = (_numberOfQuestions + 1).clamp(1, _maxQuestions).toDouble())
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _maxQuestions > 0 ? 'max: $_maxQuestions' : 'Aucune question disponible pour la sélection actuelle',
                  style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.14),
                  Colors.white.withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Text('Mode', style: GoogleFonts.montserrat(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        _SegmentButton(
                          label: 'Étude',
                          selected: _selectedMode == QcmMode.study,
                          onTap: () => setState(() => _selectedMode = QcmMode.study),
                        ),
                        _SegmentButton(
                          label: 'Examen',
                          selected: _selectedMode == QcmMode.exam,
                          onTap: () => setState(() => _selectedMode = QcmMode.exam),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Local helpers to match Q/R controls
  Widget _RoundIconButton({required IconData icon, required VoidCallback? onTap}) {
    final bool disabled = onTap == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.circle,
        radius: 24,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: disabled ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.18),
            border: Border.all(color: Colors.white.withOpacity(disabled ? 0.2 : 0.35)),
          ),
          child: Icon(icon, size: 18, color: Colors.white.withOpacity(disabled ? 0.4 : 1.0)),
        ),
      ),
    );
  }

  Widget _SegmentButton({required String label, required bool selected, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF50E3C2).withOpacity(0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? const Color(0xFF50E3C2) : Colors.transparent),
          ),
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _startQuiz() {
    if (_selectedCategories.isEmpty) return;

    _questionsFuture.then((data) {
      final List<QcmQuestion> selectedQuestions = [];
      for (var category in _selectedCategories) {
        selectedQuestions.addAll(data[category] ?? []);
      }
      selectedQuestions.shuffle();

      late final List<QcmQuestion> quizQuestions;
      int? duration;
      if (_selectedMode == QcmMode.study) {
        quizQuestions = selectedQuestions.take(_numberOfQuestions.toInt()).toList();
      } else {
        // Exam mode: automatic number of questions (use all selected)
        quizQuestions = List<QcmQuestion>.from(selectedQuestions);
        duration = _selectedExamDuration;
      }

      if (quizQuestions.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QcmQuizScreen(
              questions: quizQuestions,
              mode: _selectedMode,
              examDurationMinutes: duration,
              selectedCategories: _selectedCategories.toList(),
            ),
          ),
        );
      }
    });
  }
}

