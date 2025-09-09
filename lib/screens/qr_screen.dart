import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/models/question.dart';
import 'package:brie_fly/services/question_service.dart';
import 'package:brie_fly/screens/quiz_screen.dart';
import 'package:brie_fly/screens/bookmarks_screen.dart';
import 'package:brie_fly/services/ads/interstitial_ad_service.dart';


class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
}

class _CategoryTile extends StatelessWidget {
  final String category;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryTile({required this.category, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.white.withOpacity(0.15),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(selected ? 0.30 : 0.18),
                    Colors.white.withOpacity(selected ? 0.18 : 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? const Color(0xFF50E3C2) : Colors.white.withOpacity(0.35),
                  width: selected ? 2 : 1.2,
                ),
                boxShadow: [
                  if (selected)
                    BoxShadow(
                      color: const Color(0xFF50E3C2).withOpacity(0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(color: Colors.white.withOpacity(0.35)),
                    ),
                    child: Icon(
                      selected ? Icons.check_circle : Icons.category_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          category,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count questions',
                          style: GoogleFonts.montserrat(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QrScreenState extends State<QrScreen> {
  final QuestionService _questionService = QuestionService();
  List<Question> _allQuestions = [];
  List<String> _categories = [];
  final Set<String> _selectedCategories = {};
  final Map<String, int> _categoryCounts = {};
  double _numberOfQuestions = 10.0;
  int _maxQuestions = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _allQuestions = await _questionService.loadQuestions();
      final allCategories = _allQuestions.map((q) => q.category).toSet().toList()
        ..sort();
      // Build counts per category
      _categoryCounts.clear();
      for (final q in _allQuestions) {
        _categoryCounts.update(q.category, (v) => v + 1, ifAbsent: () => 1);
      }
      setState(() {
        _categories = allCategories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error, e.g., show a snackbar
      print('Failed to load questions: $e');
    }
  }

  void _updateMaxQuestions() {
    if (_selectedCategories.isEmpty) {
      _maxQuestions = 0;
    } else {
      _maxQuestions = _allQuestions
          .where((q) => _selectedCategories.contains(q.category))
          .length;
    }

    if (_numberOfQuestions > _maxQuestions) {
      _numberOfQuestions = _maxQuestions.toDouble();
    }
    if (_maxQuestions > 0 && _numberOfQuestions < 1) {
      _numberOfQuestions = 1.0;
    }
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
      _updateMaxQuestions();
    });
  }

  Future<void> _startQuiz() async {
    if (_selectedCategories.isEmpty) return;

    final selectedQuestions = _allQuestions
        .where((q) => _selectedCategories.contains(q.category))
        .toList();

    selectedQuestions.shuffle();

    final quizQuestions = selectedQuestions.take(_numberOfQuestions.toInt()).toList();

    // Show interstitial before starting (if available)
    await InterstitialAdService.loadIfNeeded();
    await InterstitialAdService.showIfAvailable();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(questions: quizQuestions),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundContainer(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Stack(
                  children: [
                  // Scrollable content; BackgroundContainer adds bottom padding for the global banner
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                                    onPressed: () => Navigator.of(context).maybePop(),
                                    tooltip: 'Retour',
                                  ),
                                  Column(
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text('Q/R',
                                            style: GoogleFonts.montserrat(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 24,
                                              letterSpacing: 1.2,
                                            )),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Questions / Réponses',
                                          style: GoogleFonts.montserrat(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
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
                            ),
                            const SizedBox(height: 16),
                            _SecondaryTitleBar(
                              title: 'Questions / Réponses (Q/R)',
                              subtitle: "Choisissez vos catégories et lancez une session",
                              onSelectAll: _categories.isNotEmpty && _selectedCategories.length != _categories.length
                                  ? () => setState(() {
                                        _selectedCategories
                                          ..clear()
                                          ..addAll(_categories);
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
                            _buildCategorySelector(),
                          ],
                        ),
                      ),
                    ),
                    // No page-level banner: BackgroundContainer provides a global bottom AdBanner
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Center(
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
        ),
        _categories.isEmpty
            ? Center(
                child: Text(
                'No categories found.\nCheck qr_data.txt format.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 16),
              ))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final double width = constraints.maxWidth;
                  final int crossAxisCount = width >= 1100
                      ? 4
                      : width >= 820
                          ? 3
                          : width >= 560
                              ? 2
                              : 1;
                  final double aspect = crossAxisCount == 1
                      ? 3.6
                      : crossAxisCount == 2
                          ? 3.0
                          : 2.8;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: aspect,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategories.contains(category);
                      final count = _categoryCounts[category] ?? 0;
                      return _CategoryTile(
                        category: category,
                        count: count,
                        selected: isSelected,
                        onTap: () => _toggleCategory(category),
                      );
                    },
                  );
                },
              ),
        if (_selectedCategories.isNotEmpty)
          _buildQuestionSlider(),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedCategories.isNotEmpty ? Colors.cyanAccent : Colors.grey.withOpacity(0.5),
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              textStyle: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onPressed: _selectedCategories.isNotEmpty ? _startQuiz : null,
            child: const Text('Lancer le quiz'),
          ),
        ),
    ],
  );
}

}

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
                // Wide (desktop) layout: title/subtitle on left, actions on right
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

