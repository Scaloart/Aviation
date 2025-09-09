import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:brie_fly/models/dossier_info.dart';
import 'package:brie_fly/screens/home_screen.dart';
import 'package:brie_fly/services/dossier_service.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brie_fly/services/cloud_dossier_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:share_plus/share_plus.dart';
import 'package:brie_fly/routes.dart';

class DossiersScreen extends StatefulWidget {
  final bool showSuccess;
  const DossiersScreen({super.key, this.showSuccess = false});

  @override
  _DossiersScreenState createState() => _DossiersScreenState();
}

class _DossiersScreenState extends State<DossiersScreen> with RouteAware {
  final DossierService _dossierService = DossierService();
  final CloudDossierService _cloud = CloudDossierService();
  List<DossierInfo> _dossiers = [];
  List<DossierInfo> _filteredDossiers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // If arriving right after generation, skip the first cloud sync so the new
    // local dossier appears instantly (cloud upload may still be in-flight).
    _loadDossiers(skipCloud: widget.showSuccess);
    _searchController.addListener(() {
      _filterDossiers(_searchController.text);
    });
    // Show success dialog after navigation if requested
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.showSuccess && mounted) {
        _showGenerationSuccessDialog();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  // Called when this route has been pushed onto the navigator.
  @override
  void didPush() {
    // Force a refresh right after the screen is shown to pick up the
    // dossier that was just saved by the generation flow.
    _loadDossiers(skipCloud: widget.showSuccess);
    // Also schedule a short delayed refresh to avoid any potential
    // race with filesystem writes on some platforms.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _loadDossiers(skipCloud: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Called when a covered route has been popped and this route shows again
  @override
  void didPopNext() {
    // Refresh dossiers when returning from generation or other flows
    _loadDossiers();
  }

  Future<void> _shareDossier(DossierInfo dossier) async {
    try {
      final file = dossier.file;
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fichier introuvable pour le partage.')),
          );
        }
        return;
      }
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf', name: file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'dossier.pdf')],
        subject: 'Dossier de vol: ${dossier.name}',
        text: 'Veuillez trouver ci-joint le PDF du dossier: ${dossier.name}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du partage: $e')),
        );
      }
    }
  }

  Future<void> _loadDossiers({bool skipCloud = false}) async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    print('[Dossiers] _loadDossiers: start');
    try {
      final user = FirebaseAuth.instance.currentUser;
      print('[Dossiers] _loadDossiers: currentUser=${user?.uid ?? 'null'}');
      if (!skipCloud && user != null) {
        // Pull from cloud first to hydrate local storage
        try {
          print('[Dossiers] _loadDossiers: calling _cloud.syncFromCloud(uid=${user.uid})');
          await _cloud.syncFromCloud(uid: user.uid);
          print('[Dossiers] _loadDossiers: syncFromCloud completed');
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            // Silent: user doesn't have rights yet; continue with local list only
            print('[Dossiers] _loadDossiers: permission-denied while syncing from cloud; continuing with local list');
          } else {
            print('[Dossiers] _loadDossiers: FirebaseException during cloud sync: ${e.code} ${e.message}');
            rethrow;
          }
        }
      }
      print('[Dossiers] _loadDossiers: listing local dossiers');
      final dossiers = await _dossierService.listDossiers();
      print('[Dossiers] _loadDossiers: local count=${dossiers.length}');
      // Default sort by production date, descending
      dossiers.sort((a, b) => b.productionDate.compareTo(a.productionDate));
      if (mounted) {
        setState(() {
          _dossiers = dossiers;
          _filteredDossiers = dossiers;
          _isLoading = false;
        });
      }
      print('[Dossiers] _loadDossiers: done; state updated (mounted=$mounted)');
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print('[Dossiers] _loadDossiers: error=$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des dossiers: $e')),
        );
      }
    }
  }

  void _filterDossiers(String query) {
    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      _filteredDossiers = _dossiers.where((dossier) {
        return dossier.name.toLowerCase().contains(lowerCaseQuery) ||
            dossier.category.toLowerCase().contains(lowerCaseQuery) ||
            dossier.id.toLowerCase().contains(lowerCaseQuery);
      }).toList();
    });
  }


  Future<void> _renameDossier(DossierInfo dossier) async {
    final newName = await _showRenameDialog(dossier.name);
    if (newName != null && newName.isNotEmpty && newName != dossier.name) {
      try {
        await _dossierService.renameDossier(dossier, newName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dossier renommé en "$newName"')),
          );
        }
        await _loadDossiers(); // Refresh list
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors du renommage: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteDossier(DossierInfo dossier) async {
    final confirmed = await _showDeleteConfirmationDialog(dossier);
    if (confirmed == true && mounted) {
      try {
        await _dossierService.deleteDossier(dossier);
        // Also delete from cloud if signed in
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await _cloud.deleteFromCloud(uid: user.uid, id: dossier.id);
          } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dossier "${dossier.name}" supprimé.')),
        );
        await _loadDossiers(); // Refresh the list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression: $e')),
        );
      }
    }
  }

  Future<bool?> _showDeleteConfirmationDialog(DossierInfo dossier) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            backgroundColor: Colors.white.withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orangeAccent,
                    size: 50,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Confirmer la suppression',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Voulez-vous vraiment supprimer le dossier "${dossier.name}" ? Cette action est irréversible.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        child: Text(
                          'Annuler',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Supprimer',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showRenameDialog(String currentName) {
    final TextEditingController renameController = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            backgroundColor: Colors.white.withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Renommer le dossier',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: renameController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nouveau nom',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le nom ne peut pas être vide.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Annuler', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E2B47),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              Navigator.of(context).pop(renameController.text.trim());
                            }
                          },
                          child: Text('Sauvegarder', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600)),
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
  }

  Widget _buildDossierList() {
    if (_filteredDossiers.isEmpty) {
      return Center(
        child: Text(
          'Aucun dossier trouvé',
          style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _filteredDossiers.length,
      itemBuilder: (context, index) {
        final dossier = _filteredDossiers[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          color: Colors.white.withOpacity(0.15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1E2B47).withOpacity(0.8),
              child: Text(
                '${index + 1}',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            title: Text(
              dossier.name,
              style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${dossier.category} • ${DateFormat('dd/MM/yy HH:mm').format(dossier.productionDate)}',
              style: GoogleFonts.montserrat(color: Colors.white70),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white70),
                  tooltip: 'Partager',
                  onPressed: () => _shareDossier(dossier),
                  splashRadius: 20,
                ),
                IconButton(
                  icon: const Icon(Icons.drive_file_rename_outline, color: Colors.lightBlueAccent),
                  tooltip: 'Renommer',
                  onPressed: () => _renameDossier(dossier),
                  splashRadius: 20,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Color(0xFFF44336)),
                  tooltip: 'Supprimer',
                  onPressed: () => _deleteDossier(dossier),
                  splashRadius: 20,
                ),
              ],
            ),
            onTap: () => OpenFile.open(dossier.filePath),
          ),
        );
      },
    );
  }

  @override
  Future<void> _deleteAllDossiers() async {
    final confirmed = await _showDeleteAllConfirmationDialog();
    if (confirmed == true && mounted) {
      try {
        print('[Dossiers] _deleteAllDossiers: user confirmed, starting deletion');
        // Log pre-delete count
        final before = await _dossierService.listDossiers();
        print('[Dossiers] _deleteAllDossiers: local count before delete=${before.length}');
        await _dossierService.deleteAllDossiers();
        print('[Dossiers] _deleteAllDossiers: local deleteAll completed');
        // Also delete from cloud if signed in, to avoid rehydration on next sync
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && before.isNotEmpty) {
          print('[Dossiers] _deleteAllDossiers: deleting ${before.length} dossiers from cloud for uid=${user.uid}');
          try {
            // Delete each dossier by id in the cloud. We use the pre-delete list to keep IDs.
            await Future.wait(before.map((d) async {
              try {
                await _cloud.deleteFromCloud(uid: user.uid, id: d.id);
                print('[Dossiers] _deleteAllDossiers: cloud deleted id=${d.id}');
              } catch (e) {
                print('[Dossiers] _deleteAllDossiers: cloud delete failed for id=${d.id}: $e');
              }
            }));
            print('[Dossiers] _deleteAllDossiers: cloud deletions completed');
          } catch (e) {
            print('[Dossiers] _deleteAllDossiers: error during bulk cloud deletions: $e');
          }
        } else {
          if (user == null) {
            print('[Dossiers] _deleteAllDossiers: no user signed in; skipping cloud deletion');
          } else {
            print('[Dossiers] _deleteAllDossiers: nothing to delete from cloud (pre-delete list empty)');
          }
        }
        final after = await _dossierService.listDossiers();
        print('[Dossiers] _deleteAllDossiers: local count after delete=${after.length}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tous les dossiers ont été supprimés.')),
          );
        } else {
          print('[Dossiers] _deleteAllDossiers: widget unmounted before snackbar');
        }
        // Note: _loadDossiers will perform cloud sync if signed in; this may rehydrate deleted items from cloud.
        // We log this flow to diagnose potential restoration from cloud.
        if (mounted) {
          print('[Dossiers] _deleteAllDossiers: calling _loadDossiers (mounted)');
          await _loadDossiers(); // Refresh the list
        } else {
          print('[Dossiers] _deleteAllDossiers: widget unmounted, skipping _loadDossiers');
        }
      } catch (e) {
        print('[Dossiers] _deleteAllDossiers: error=$e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression de tous les dossiers: $e')),
          );
        }
      }
    }
  }

  Future<bool?> _showDeleteAllConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            backgroundColor: Colors.white.withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 50,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Supprimer tous les dossiers ?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Cette action est irréversible et supprimera tous les dossiers stockés.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        child: Text(
                          'Annuler',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Tout supprimer',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher par nom, catégorie, N°...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.white),
                )
              : Text('Dossiers Générés', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                  }
                });
              },
            ),
            if (!_isSearching)
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Tout supprimer',
                onPressed: _dossiers.isEmpty ? null : _deleteAllDossiers,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _buildDossierList(),
      ),
    );
  }

  Future<void> _showGenerationSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              backgroundColor: Colors.transparent,
              child: SafeArea(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF101214), Color(0xFF1A1F24), Color(0xFF22282E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, 8)),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: Image.asset(
                            'assets/Logos/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, _, __) {
                              return Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, __, ___) {
                                  return Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'EPL3',
                                      style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'Dossier prêt',
                              style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.9)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Votre dossier de vol a été généré et sauvegardé avec succès.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white.withOpacity(0.8)),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(Icons.folder_outlined, color: Colors.white70, size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Accédez à vos dossiers pour consulter, partager ou supprimer des fichiers.',
                                    style: GoogleFonts.montserrat(fontSize: 13, color: Colors.white70),
                                    softWrap: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              OutlinedButton(
                                onPressed: () => Navigator.of(dialogContext).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white.withOpacity(0.85),
                                  side: BorderSide(color: Colors.white.withOpacity(0.6)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  minimumSize: const Size(100, 44),
                                ),
                                child: Text('Fermer', style: GoogleFonts.montserrat()),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(dialogContext).pop(),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  minimumSize: const Size(140, 44),
                                ),
                                child: Text('Voir les dossiers', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
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
          ),
        );
      },
    );
  }
}

