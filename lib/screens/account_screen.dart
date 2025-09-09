import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:brie_fly/services/auth_service.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/main.dart';
import 'package:brie_fly/models/app_user.dart';
import 'package:brie_fly/services/purchase_service.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brie_fly/services/paypal_service.dart';
// removed duplicate provider import

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final GlobalKey<_SubscriptionStatusViewState> subscriptionStatusKey = GlobalKey<_SubscriptionStatusViewState>();
  bool _isLogin = true;
  bool _showVerifyBanner = false;

  void _toggleFormType() {
    setState(() {
      _isLogin = !_isLogin;
      _showVerifyBanner = false; // reset banner on toggle
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (user == null || (user != null && !user.emailVerified)) {
          return BackgroundContainer(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                            maxWidth: 600,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Main content
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildAppTitle(isDesktop: false),
                                    const SizedBox(height: 16),
                                    if (_showVerifyBanner)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.15),
                                          border: Border.all(color: Colors.orangeAccent),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Vous devez confirmer votre compte via le lien envoyé par email.',
                                          style: GoogleFonts.montserrat(color: Colors.orangeAccent),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    const SizedBox(height: 24),
                                    AuthCard(
                                      isLogin: _isLogin,
                                      onToggle: _toggleFormType,
                                      onRequireVerification: () {
                                        setState(() => _showVerifyBanner = true);
                                      },
                                    ),
                                  ],
                                ),
                                // Footer as normal bottom content (scrolls when content long)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 20.0, top: 16.0),
                                  child: _buildSignature(),
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
          );
        } else {
          // User is logged in, show subscription status
          return Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: Text('Mon Compte',
                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.black.withOpacity(0.2),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    subscriptionStatusKey.currentState?.refreshData();
                  },
                ),
              ],
            ),
            body: BackgroundContainer(
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                      child: SubscriptionStatusView(key: subscriptionStatusKey),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }



  Widget _buildAppTitle({required bool isDesktop}) {
    final titleSize = isDesktop ? 56.0 : 42.0;
    final subtitleSize = isDesktop ? 32.0 : 26.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AutoSizeText(
          'Briefly',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: titleSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(2.0, 2.0),
              ),
            ],
          ),
          maxLines: 1,
        ),
        const SizedBox(height: 16),
        AutoSizeText(
          'All You Need To Fly 😉',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Columbia',
            fontSize: subtitleSize,
            fontWeight: FontWeight.normal,
            color: Colors.white70,
          ),
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildSignature() {
    return InkWell(
      onTap: () async {
        final Uri url = Uri.parse('https://www.instagram.com/nassihsalah');
        if (!await launchUrl(url)) {
          debugPrint('Could not launch $url');
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'NASSIH | EPL 03',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.7),
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class AuthCard extends StatefulWidget {
  final bool isLogin;
  final VoidCallback onToggle;
  final VoidCallback onRequireVerification;

  const AuthCard({super.key, required this.isLogin, required this.onToggle, required this.onRequireVerification});

  @override
  State<AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends State<AuthCard> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _forgotEmailController = TextEditingController();
  String _email = '';
  String _password = '';
  String _name = '';
  String _errorMessage = '';
  bool _isLoading = false;

  @override
  void didUpdateWidget(covariant AuthCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLogin != widget.isLogin) {
      // Reset form and clear transient values when switching modes
      _formKey.currentState?.reset();
      _passwordController.clear();
      _email = '';
      _password = '';
      _name = '';
      _errorMessage = '';
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _forgotEmailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = context.read<AuthService>();
      if (widget.isLogin) {
        await authService.signIn(email: _email, password: _password);
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !user.emailVerified) {
          // Resend verification and surface the yellow banner via parent callback. Do not sign out.
          try { await user.sendEmailVerification(); } catch (_) {}
          if (mounted) {
            widget.onRequireVerification();
          }
          return; // stop further flow
        }
      } else {
        await authService.signUp(email: _email, password: _password, name: _name);
        // Send email verification
        try {
          await FirebaseAuth.instance.currentUser?.sendEmailVerification();
        } catch (_) {}
        // Sign out so user is not considered logged in until verification
        try { await FirebaseAuth.instance.signOut(); } catch (_) {}
        if (mounted) {
          await _showSignUpConfirmation(name: _name, email: _email);
          widget.onToggle(); // Switch to login form
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'An unknown error occurred.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showSignUpConfirmation({required String name, required String email}) async {
    final themeTextStyle = GoogleFonts.montserrat(color: Colors.white);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.85),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Inscription réussie', style: themeTextStyle.copyWith(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bienvenue${name.isNotEmpty ? ', ' + name : ''}!', style: themeTextStyle),
              const SizedBox(height: 8),
              Text('Votre compte (${email.isNotEmpty ? email : 'email non renseigné'}) a été créé.', style: themeTextStyle.copyWith(color: Colors.white70)),
              const SizedBox(height: 12),
              Text('Nous avons envoyé un email de vérification. Veuillez vérifier votre boîte de réception et cliquer sur le lien pour activer votre compte.', style: themeTextStyle.copyWith(color: Colors.white70)),
              const SizedBox(height: 12),
              Text('Vous pouvez maintenant vous connecter.', style: themeTextStyle.copyWith(color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fermer'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              child: const Text('Se connecter'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEmailVerificationRequired({required String email}) async {
    final themeTextStyle = GoogleFonts.montserrat(color: Colors.white);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.85),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Vérification requise', style: themeTextStyle.copyWith(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Votre email (${email.isNotEmpty ? email : '—'}) n\'est pas encore vérifié.', style: themeTextStyle),
              const SizedBox(height: 12),
              Text('Veuillez ouvrir l\'email de vérification et cliquer sur le lien pour activer votre compte, puis réessayez de vous connecter.', style: themeTextStyle.copyWith(color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showResetPasswordDialog() async {
    if (_email.isNotEmpty && _forgotEmailController.text.isEmpty) {
      _forgotEmailController.text = _email;
    }
    final themeTextStyle = GoogleFonts.montserrat(color: Colors.white);
    String? localError;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final width = MediaQuery.of(ctx).size.width;
        final isDesktop = width >= 800; // Windows/desktop responsive tweak
        final dialogMaxWidth = isDesktop ? 520.0 : 420.0;

        final emailFocus = FocusNode();
        bool isSending = false;

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> doSend() async {
              if (isSending) return;
              final email = _forgotEmailController.text.trim();
              final emailRegex = RegExp(r'^.+@.+\..+$');
              if (email.isEmpty || !emailRegex.hasMatch(email)) {
                setStateDialog(() => localError = 'Entrez un email valide');
                return;
              }
              setStateDialog(() { isSending = true; localError = null; });
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (context.mounted) {
                  Navigator.of(ctx).pop();
                  await showDialog<void>(
                    context: context,
                    builder: (ctx2) {
                      return AlertDialog(
                        backgroundColor: Colors.black.withOpacity(0.85),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.lightGreenAccent),
                            const SizedBox(width: 8),
                            Text('Email envoyé', style: themeTextStyle.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        content: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: dialogMaxWidth),
                          child: Text('Un email de réinitialisation a été envoyé à $email. Vérifiez votre boîte de réception et suivez les instructions.',
                              style: themeTextStyle.copyWith(color: Colors.white70)),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx2).pop(), child: const Text('OK')),
                        ],
                      );
                    },
                  );
                }
              } on FirebaseAuthException catch (e) {
                setStateDialog(() => localError = e.message ?? 'Erreur lors de l\'envoi de l\'email.');
              } catch (_) {
                setStateDialog(() => localError = 'Une erreur est survenue.');
              } finally {
                setStateDialog(() => isSending = false);
              }
            }

            // Request focus when dialog builds the first time
            if (!emailFocus.hasFocus) {
              // Slight delay to ensure focus after build
              Future.microtask(() => emailFocus.requestFocus());
            }

            return AlertDialog(
              backgroundColor: Colors.black.withOpacity(0.85),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              title: Text('Mot de passe oublié', style: themeTextStyle.copyWith(fontWeight: FontWeight.bold)),
              content: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: dialogMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Entrez votre email pour recevoir un lien de réinitialisation.', style: themeTextStyle.copyWith(color: Colors.white70)),
                    const SizedBox(height: 12),
                    TextField(
                      focusNode: emailFocus,
                      enabled: !isSending,
                      controller: _forgotEmailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => doSend(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(Icons.email, color: Colors.white60, size: 20),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Colors.blue, width: 1.5)),
                        errorText: localError,
                        errorStyle: const TextStyle(color: Colors.orangeAccent),
                        helperText: 'Nous vous enverrons un lien sécurisé',
                        helperStyle: const TextStyle(color: Colors.white38),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton.icon(
                  onPressed: isSending ? null : doSend,
                  icon: isSending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, size: 18),
                  label: Text(isSending ? 'Envoi...' : 'Envoyer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isLogin ? 'Content de vous revoir' : 'Créer un compte',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                if (!widget.isLogin)
                  _buildTextField(
                    fieldKey: const ValueKey('nameField'),
                    label: 'Nom',
                    icon: Icons.person,
                    validator: (val) => val!.isEmpty ? 'Entrez votre nom' : null,
                    onSaved: (val) => _name = val!,
                  ),
                if (!widget.isLogin) const SizedBox(height: 16),
                _buildTextField(
                  fieldKey: const ValueKey('emailField'),
                  label: 'Email',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val!.isEmpty ? 'Entrez un email' : null,
                  onSaved: (val) => _email = val!,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  fieldKey: const ValueKey('passwordField'),
                  label: 'Mot de passe',
                  icon: Icons.lock,
                  obscureText: true,
                  controller: _passwordController,
                  validator: (val) => val!.length < 6 ? 'Entrez un mot de passe de 6 caractères ou plus' : null,
                  onSaved: (val) => _password = val!,
                ),
                if (widget.isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showResetPasswordDialog,
                      child: const Text('Mot de passe oublié ?', style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                if (!widget.isLogin) const SizedBox(height: 16),
                if (!widget.isLogin)
                  _buildTextField(
                    fieldKey: const ValueKey('confirmPasswordField'),
                    label: 'Confirmez le mot de passe',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    validator: (val) => val != _passwordController.text ? 'Les mots de passe ne correspondent pas' : null,
                  ),
                const SizedBox(height: 24),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(widget.isLogin ? 'Connexion' : 'S\'inscrire'),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: widget.onToggle,
                  child: Text(
                    widget.isLogin ? 'Pas de compte ? S\'inscrire' : 'Déjà un compte ? Se connecter',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    Key? fieldKey,
    required String label,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
    TextInputType? keyboardType,
    TextEditingController? controller,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.white60, size: 20),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.orangeAccent),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.orangeAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.orangeAccent, width: 1.5),
        ),
      ),
      obscureText: obscureText,
      validator: validator,
      onSaved: onSaved,
      keyboardType: keyboardType,
    );
  }
}

class SubscriptionStatusView extends StatefulWidget {
  const SubscriptionStatusView({super.key});

  @override
  State<SubscriptionStatusView> createState() => _SubscriptionStatusViewState();
}

class _SubscriptionStatusViewState extends State<SubscriptionStatusView> {
  bool _isLoading = true;
  String _subscriptionType = 'Gratuit';
  String _provider = '—';
  String _planLabel = '—';
  String _expiryStr = '—';

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionData();
  }

  Future<void> refreshData() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchSubscriptionData();
  }

  Future<void> _fetchSubscriptionData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted && doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final sub = (data['subscription'] ?? {}) as Map<String, dynamic>;

        final type = sub['type'] as String?;
        final provider = sub['provider'] as String?;
        final planId = sub['planId'] as String?;
        final expiry = sub['expiryDate'] as Timestamp?;

        final paypal = PaypalService();
        final offerId = (planId != null) ? paypal.planIdToOffer[planId] : null;

        setState(() {
          _subscriptionType = type == 'premium' ? 'Premium' : 'Gratuit';
          _provider = provider ?? '—';
          _planLabel = _getPlanLabel(offerId);
          _expiryStr = (type == 'premium') ? _formatDate(expiry) : '—';
        });
      }
    } catch (e) {
      debugPrint('Failed to load subscription data: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  String _getPlanLabel(String? offerId) {
    switch (offerId) {
      case 'monthly_mock':
        return 'Mensuel';
      case 'six_months_mock':
        return '6 Mois';
      case 'annual_mock':
        return 'Annuel';
      default:
        return 'Inconnu';
    }
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate().toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statut d\'abonnement',
                style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_subscriptionType == 'Premium' ? Icons.star : Icons.lock_open,
                          color: _subscriptionType == 'Premium' ? const Color(0xFFFFD700) : Colors.white70),
                      const SizedBox(width: 10),
                      Text(
                        _subscriptionType == 'Premium' ? 'Premium ($_planLabel)' : 'Gratuit',
                        style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoRow('Fournisseur', _provider),
                  _infoRow('Expiration', _expiryStr),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: GoogleFonts.montserrat(color: Colors.white70))),
          Expanded(child: Text(value, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

