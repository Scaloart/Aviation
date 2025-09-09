import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/models/app_user.dart';
import 'package:brie_fly/services/auth_service.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/widgets/user_avatar.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'dart:io' show Platform;
import 'package:brie_fly/services/theme_service.dart';
import 'package:brie_fly/auth_wrapper.dart';

class SettingsScreen extends StatefulWidget {
  final AppUser user;
  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream;
  late final AuthService _authService;
  final ScrollController _bgScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .snapshots();
  }

  @override
  void dispose() {
    _bgScrollController.dispose();
    super.dispose();
  }

  Future<void> _showEditNameDialog(AppUser currentUser) async {
    final nameController = TextEditingController(text: currentUser.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2C3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Changer de nom', style: GoogleFonts.montserrat(color: Colors.white)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Annuler', style: GoogleFonts.montserrat(color: Colors.white70))),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(nameController.text),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF50E3C2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Enregistrer', style: GoogleFonts.montserrat(color: Colors.black)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != currentUser.name) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({'name': newName});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data?.data() == null) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: Text('Error loading user data.')),
          );
        }

        final appUser = AppUser.fromFirestore(snapshot.data!);

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          body: BackgroundContainer(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  // In-body header row below custom window bar
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: 'Retour',
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Paramètres',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // balance row height where an action button would be
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: UserAvatar(
                      avatarUrl: appUser.avatarUrl,
                      userId: appUser.uid,
                      radius: 60,
                      editable: true,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildSettingsCard(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      title: Text('Nom', style: GoogleFonts.montserrat(color: Colors.white.withOpacity(0.7))),
                      subtitle: Text(appUser.name, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.edit, color: Colors.white70),
                      onTap: () => _showEditNameDialog(appUser),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingsCard(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      title: Text('Email', style: GoogleFonts.montserrat(color: Colors.white.withOpacity(0.7))),
                      subtitle: Text(appUser.email, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text('Gestion du compte', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildSettingsCard(
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.lock_outline,
                          text: 'Changer le mot de passe',
                          onTap: () => _showChangePasswordDialog(),
                        ),
                        const Divider(color: Colors.white24, height: 1),
                        _buildMenuItem(
                          icon: Icons.delete_outline,
                          text: 'Supprimer le compte',
                          textColor: Colors.redAccent,
                          onTap: () => _showDeleteConfirmationDialog(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildAppearanceSection(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({required IconData icon, required String text, required VoidCallback onTap, Color? textColor}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      leading: Icon(icon, color: textColor ?? Colors.white70),
      title: Text(text, style: GoogleFonts.montserrat(color: textColor ?? Colors.white, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.arrow_forward_ios, color: textColor ?? Colors.white70, size: 16),
      onTap: onTap,
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2C3D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Changer de mot de passe', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: oldPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: 'Ancien mot de passe', labelStyle: const TextStyle(color: Colors.white70)),
                  validator: (value) => value!.isEmpty ? 'Champ requis' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: 'Nouveau mot de passe', labelStyle: const TextStyle(color: Colors.white70)),
                  validator: (value) => value!.length < 6 ? '6 caractères minimum' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await _authService.changePassword(
                      oldPassword: oldPasswordController.text,
                      newPassword: newPasswordController.text,
                    );
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mot de passe changé avec succès.'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final passwordController = TextEditingController();
    final isDesktop = kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isObscure = true;
        bool confirmIrreversible = false;
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            final canDelete = confirmIrreversible && passwordController.text.isNotEmpty && !isLoading;
            return Dialog(
              backgroundColor: const Color(0xFF102331),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 560 : 420),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Supprimer le compte',
                                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Cette action est irréversible et supprimera définitivement vos données associées à ce compte.',
                                  style: GoogleFonts.montserrat(color: Colors.white70, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: passwordController,
                        obscureText: isObscure,
                        style: const TextStyle(color: Colors.white),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
                          suffixIcon: IconButton(
                            icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                            onPressed: () => setState(() => isObscure = !isObscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        value: confirmIrreversible,
                        onChanged: (val) => setState(() => confirmIrreversible = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: Colors.redAccent,
                        checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        contentPadding: EdgeInsets.zero,
                        title: Text('Je comprends que cette action est irréversible', style: GoogleFonts.montserrat(color: Colors.white70)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withOpacity(0.4)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: canDelete
                                  ? () async {
                                      setState(() => isLoading = true);
                                      try {
                                        await _authService.deleteAccount(passwordController.text);
                                        if (mounted) {
                                          Navigator.of(context).pushAndRemoveUntil(
                                            MaterialPageRoute(builder: (_) => const AuthWrapper()),
                                            (route) => false,
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          final msg = e.toString().replaceFirst('Exception: ', '');
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: Text('Erreur: $msg'),
                                            backgroundColor: Colors.redAccent,
                                          ));
                                        }
                                      } finally {
                                        if (mounted) setState(() => isLoading = false);
                                      }
                                    }
                                  : null,
                              icon: isLoading
                                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withOpacity(0.9)))
                                  : const Icon(Icons.delete_outline),
                              label: const Text('Supprimer définitivement'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
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
      },
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDesktop = kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Apparence',
            style: GoogleFonts.montserrat(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (isDesktop)
          _buildSettingsCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                height: 100,
                child: Scrollbar(
                  controller: _bgScrollController,
                  thumbVisibility: true,
                  trackVisibility: false,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.stylus,
                        PointerDeviceKind.unknown,
                      },
                    ),
                    child: ListView.builder(
                      controller: _bgScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: themeService.availableBackgrounds.length,
                      itemBuilder: (context, index) {
                        final backgroundPath = themeService.availableBackgrounds[index];
                        final isSelected = themeService.selectedBackground == backgroundPath;
                        return GestureDetector(
                          onTap: () => themeService.setBackground(backgroundPath),
                          child: Container(
                            width: 177, // ~16:9 for 100 height
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(color: const Color(0xFF50E3C2), width: 3)
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Image.asset(
                                  backgroundPath,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          _buildSettingsCard(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                height: 180, // taller for portrait previews
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: themeService.availableBackgrounds.length,
                  itemBuilder: (context, index) {
                    final backgroundPath = themeService.availableBackgrounds[index];
                    final isSelected = themeService.selectedBackground == backgroundPath;
                    return GestureDetector(
                      onTap: () => themeService.setBackground(backgroundPath),
                      child: Container(
                        width: 110, // ~9:16 for 180 height
                        margin: EdgeInsets.only(right: index == themeService.availableBackgrounds.length - 1 ? 0 : 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: const Color(0xFF50E3C2), width: 3)
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 9 / 16,
                            child: Image.asset(
                              backgroundPath,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSettingsCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
      ),
      child: child,
    );
  }
}

