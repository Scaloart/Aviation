import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/services/bookmarks_service.dart';
import 'package:glassmorphism/glassmorphism.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final BookmarksService _service = BookmarksService();
  late Future<List<BookmarkItem>> _future;
  final Set<String> _expandedAnswers = {};
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    // Pull latest from cloud first, then show merged local list
    _future = _service.syncFromCloud().then((_) => _service.getAll());
    _searchController.addListener(() {
      final v = _searchController.text;
      if (v != _search) setState(() => _search = v);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _canShowAnswer(BookmarkItem item) {
    if (item.type == 'qr') {
      return (item.answerText != null && item.answerText!.trim().isNotEmpty);
    }
    // QCM: need correctIndex and options available
    return item.correctIndex >= 0 && item.options.isNotEmpty && item.correctIndex < item.options.length;
  }

  Widget _buildQrAnswer(String answer) {
    final regex = RegExp(r'IMG:::(\S+)');
    final matches = regex.allMatches(answer).toList();
    // Text before the first image marker
    final firstMatch = matches.isNotEmpty ? matches.first : null;
    final textBefore = firstMatch == null ? answer.trim() : answer.substring(0, firstMatch.start).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (textBefore.isNotEmpty)
          Text(
            textBefore,
            style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        for (final m in matches)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(m.group(1)!, fit: BoxFit.contain),
            ),
          ),
      ],
    );
  }

  // Render QR question text with optional image using the same 'IMG:::' convention
  Widget _buildQrQuestion(String question) {
    final parts = question.split('IMG:::');
    final textPart = parts[0].trim();
    final imagePath = parts.length > 1 ? parts[1].trim() : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (textPart.isNotEmpty)
          Text(
            textPart,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        if (imagePath != null && imagePath.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(imagePath, fit: BoxFit.cover, height: 120),
            ),
          ),
      ],
    );
  }

  Future<void> _refresh() async {
    await _service.syncFromCloud();
    setState(() {
      _future = _service.getAll();
    });
  }

  Future<void> _editNote(BookmarkItem item) async {
    final controller = TextEditingController(text: item.note ?? '');
    String? result = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: GlassmorphicContainer(
            width: double.infinity,
            height: MediaQuery.of(ctx).size.height * 0.55,
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
                    Row(
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
                        if ((item.note ?? '').isNotEmpty)
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (result != null) {
      final text = result.isEmpty ? null : result;
      await _service.updateNote(item.id, text);
      // Ensure it stays bookmarked if note exists; preserve new fields
      if (text != null) {
        await _service.upsert(BookmarkItem(
          id: item.id,
          category: item.category,
          question: item.question,
          options: item.options,
          dateAdded: item.dateAdded,
          note: text,
          correctIndex: item.correctIndex,
          type: item.type,
          answerText: item.answerText,
        ));
      }
      await _refresh();
    }
  }

  Future<void> _confirmClearAll() async {
    final count = (await _service.getAll()).length;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        bool acknowledged = false;
        final isWindows = defaultTargetPlatform == TargetPlatform.windows;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: GlassmorphicContainer(
              width: isWindows ? 520 : double.infinity,
              height: MediaQuery.of(ctx).size.height * (isWindows ? 0.32 : 0.36),
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
              child: StatefulBuilder(
                builder: (ctx, setLocal) => Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Close icon top-left, content centered
                      Stack(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              tooltip: 'Fermer',
                              icon: const Icon(Icons.close, color: Colors.white70),
                              onPressed: () => Navigator.of(ctx).pop(false),
                            ),
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33FF5252)),
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Effacer tous les favoris',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        count == 0
                            ? 'Aucun favori à supprimer.'
                            : 'Cette action supprimera ${count} favori(s) et toutes les notes associées.',
                        style: GoogleFonts.montserrat(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'La suppression s\'appliquera localement ET sur le cloud. Cette action est irréversible.',
                        style: GoogleFonts.montserrat(color: Colors.white60, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: acknowledged,
                            activeColor: Colors.cyanAccent,
                            onChanged: (v) => setLocal(() => acknowledged = v ?? false),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Je comprends les conséquences de cette action.',
                              style: GoogleFonts.montserrat(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              minimumSize: const Size(0, 0),
                            ),
                            child: const Text('Annuler', style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton.icon(
                            onPressed: acknowledged && count > 0 ? () => Navigator.of(ctx).pop(true) : null,
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Supprimer tout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5252),
                              disabledBackgroundColor: const Color(0x44FF5252),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              minimumSize: const Size(0, 0),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (ok == true) {
      await _service.clearAll();
      await _refresh();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundContainer(
        child: SafeArea(
          child: FutureBuilder<List<BookmarkItem>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              final items = snapshot.data ?? const [];
              final query = _search.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? items
                  : items.where((it) {
                      final hay = '${it.question} ${it.category} ${it.note ?? ''}'.toLowerCase();
                      return hay.contains(query);
                    }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // In-body header matching other screens
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          tooltip: 'Retour',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text('Favoris',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 24,
                                    letterSpacing: 1.2,
                                  )),
                              const SizedBox(height: 4),
                              Text(
                                items.isEmpty ? 'Aucun favori' : '${items.length} favoris enregistrés',
                                style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tout effacer',
                          icon: const Icon(Icons.delete_sweep, color: Colors.white),
                          onPressed: _confirmClearAll,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, color: Colors.white70),
                            suffixIcon: _search.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.white70),
                                    onPressed: () => _searchController.clear(),
                                  ),
                            hintText: 'Rechercher… (question, catégorie, note)',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.10),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.cyanAccent),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (_search.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        '${filtered.length} résultat(s)',
                        style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 12),
                      ),
                    ),

                  // Content
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text('Aucun favori pour le moment',
                                style: GoogleFonts.montserrat(color: Colors.white70)),
                          )
                        : RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, idx) {
                                final item = filtered[idx];
                                final isExpanded = _expandedAnswers.contains(item.id);
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                    child: Container(
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
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            ListTile(
                                              leading: const Icon(Icons.bookmark, color: Colors.cyanAccent),
                                              title: item.type == 'qr' && item.question.contains('IMG:::')
                                                  ? _buildQrQuestion(item.question)
                                                  : Text(
                                                      item.question,
                                                      maxLines: 3,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700),
                                                    ),
                                              subtitle: Padding(
                                                padding: const EdgeInsets.only(top: 6.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Catégorie: ${item.category}',
                                                        style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 12)),
                                                    if (item.note != null && item.note!.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text('Note: ${item.note}',
                                                          style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 12)),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    tooltip: 'Éditer la note',
                                                    icon: const Icon(Icons.edit_note, color: Colors.white70),
                                                    onPressed: () => _editNote(item),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Supprimer des favoris',
                                                    icon: const Icon(Icons.delete_outline, color: Colors.white70),
                                                    onPressed: () async {
                                                      await _service.remove(item.id);
                                                      await _refresh();
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                              child: Row(
                                                children: [
                                                  TextButton.icon(
                                                    onPressed: _canShowAnswer(item)
                                                        ? () {
                                                            setState(() {
                                                              if (isExpanded) {
                                                                _expandedAnswers.remove(item.id);
                                                              } else {
                                                                _expandedAnswers.add(item.id);
                                                              }
                                                            });
                                                          }
                                                        : null,
                                                    icon: Icon(isExpanded ? Icons.visibility_off : Icons.visibility, color: Colors.cyanAccent),
                                                    label: Text(isExpanded ? 'Masquer la réponse' : 'Afficher la réponse',
                                                        style: GoogleFonts.montserrat(color: Colors.white)),
                                                  ),
                                                  if (!_canShowAnswer(item))
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 8.0),
                                                      child: Text('Réponse indisponible', style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12)),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (isExpanded)
                                              Padding(
                                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                                                child: item.type == 'qr'
                                                    ? _buildQrAnswer(item.answerText ?? '')
                                                    : Column(
                                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                                        children: List.generate(item.options.length, (i) {
                                                          final isCorrect = i == item.correctIndex;
                                                          return Container(
                                                            margin: const EdgeInsets.only(top: 8),
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                            decoration: BoxDecoration(
                                                              color: isCorrect ? Colors.green.withOpacity(0.18) : Colors.white.withOpacity(0.06),
                                                              border: Border.all(color: isCorrect ? Colors.greenAccent.withOpacity(0.6) : Colors.white24),
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Row(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Icon(isCorrect ? Icons.check_circle : Icons.circle_outlined,
                                                                    size: 18, color: isCorrect ? Colors.greenAccent : Colors.white54),
                                                                const SizedBox(width: 8),
                                                                Expanded(
                                                                  child: Text(
                                                                    item.options[i],
                                                                    style: GoogleFonts.montserrat(color: Colors.white, fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w500),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        }),
                                                      ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

