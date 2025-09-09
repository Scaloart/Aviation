import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/widgets/background_container.dart';

class ManualPaymentScreen extends StatefulWidget {
  final int months; // 1, 6, 12
  final String priceLabel; // e.g., "50 MAD/mois", "100 MAD/6 mois", "200 MAD/an"

  const ManualPaymentScreen({super.key, required this.months, required this.priceLabel});

  @override
  State<ManualPaymentScreen> createState() => _ManualPaymentScreenState();
}

class _ManualPaymentScreenState extends State<ManualPaymentScreen> {
  bool _uploading = false;
  PlatformFile? _pickedFile;
  String? _uploadedUrl;

  // TODO: replace with your real details
  static const String holderName = 'SALAHEDDINE NASSIH';
  static const String bankName = 'CIH Bank';
  static const String ribIban = 'RIB : 230 780 4018357211029900 64';

  bool get _isDesktop => !kIsWeb && !(Platform.isAndroid || Platform.isIOS);

  Future<void> _pickProof() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.single);
    }
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez vous connecter.'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez sélectionner une capture du virement.'),
        backgroundColor: Colors.amber,
      ));
      return;
    }

    try {
      setState(() => _uploading = true);
      final storage = FirebaseStorage.instance;
      final path = 'manual_payments/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}';

      UploadTask uploadTask;
      if (_pickedFile!.bytes != null) {
        uploadTask = storage.ref(path).putData(_pickedFile!.bytes!);
      } else if (_pickedFile!.path != null) {
        uploadTask = storage.ref(path).putFile(File(_pickedFile!.path!));
      } else {
        throw Exception('Fichier invalide.');
      }

      final snap = await uploadTask.whenComplete(() {});
      final url = await snap.ref.getDownloadURL();
      _uploadedUrl = url;

      final docRef = await FirebaseFirestore.instance.collection('manual_payments').add({
        'uid': user.uid,
        'status': 'pending',
        'durationMonths': widget.months,
        'proofUrl': url,
        'bank': bankName,
        'holder': holderName,
        'ribIban': ribIban,
        'priceLabel': widget.priceLabel,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Reçu envoyé. Référence: ${docRef.id}'),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur d\'envoi: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      body: BackgroundContainer(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Retour',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Virement Bancaire',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Informations de paiement',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Veuillez effectuer un virement bancaire puis téléverser une capture (PNG/JPG/PDF).',
                                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.88)),
                                  ),
                                  const SizedBox(height: 24),
                                  _InfoTile(icon: Icons.person_outline, label: 'Titulaire', value: holderName),
                                  _InfoTile(icon: Icons.account_balance_outlined, label: 'Banque', value: bankName),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: _InfoTile(
                                          icon: Icons.credit_card_outlined,
                                          label: 'RIB/IBAN',
                                          value: ribIban,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message: 'Copier',
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: () async {
                                            await Clipboard.setData(const ClipboardData(text: ribIban));
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('RIB/IBAN copié dans le presse-papiers')),
                                            );
                                          },
                                          icon: const Icon(Icons.copy_rounded, size: 18),
                                          label: const Text('Copier'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 32, color: Colors.white24),
                                  Text(
                                    'Offre sélectionnée',
                                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${widget.priceLabel}  |  ${widget.months} mois',
                                    style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 6,
                            child: _GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Téléverser la preuve',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.colorScheme.primary,
                                          foregroundColor: theme.colorScheme.onPrimary,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: _uploading ? null : _pickProof,
                                        icon: const Icon(Icons.attach_file_rounded),
                                        label: const Text('Choisir un fichier'),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _pickedFile?.name ?? 'Aucun fichier sélectionné',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, color: Colors.white70),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Formats acceptés: PNG, JPG, JPEG, PDF. Taille recommandée < 10 Mo.',
                                            style: GoogleFonts.inter(color: Colors.white70),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.greenAccent.shade400,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      onPressed: _uploading ? null : _submit,
                                      child: _uploading
                                          ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                            )
                                          : Text('Envoyer la preuve', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                  if (_uploadedUrl != null) ...[
                                    const SizedBox(height: 12),
                                    SelectableText(
                                      'Lien du reçu: $_uploadedUrl',
                                      style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9)),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon; 
  final String label; 
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(color: Colors.white70)),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
