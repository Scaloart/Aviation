import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class UserAvatar extends StatefulWidget {
  final String? avatarUrl;
  final String userId;
  final double radius;
  final bool editable;
  final IconData placeholderIcon;

  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.userId,
    this.radius = 50,
    this.editable = false,
    this.placeholderIcon = Icons.person,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    if (!widget.editable) return;

    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final file = File(pickedFile.path);
      debugPrint('Image picked: ${file.path}');

      // Store avatar under a per-user folder to satisfy Storage rules: user_avatars/{uid}/{file}
      final storagePath = 'user_avatars/${widget.userId}/avatar.jpg';
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      debugPrint('Storage reference: ${ref.fullPath}');

      debugPrint('Starting upload...');
      final uploadTask = ref.putFile(file);
      
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        debugPrint('Upload progress: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100}%');
      });

      final snapshot = await uploadTask.whenComplete(() => debugPrint('Upload complete.'));
      debugPrint('Bytes transferred: ${snapshot.bytesTransferred}');

      debugPrint('Getting download URL...');
      final newAvatarUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Got download URL: $newAvatarUrl');

      debugPrint('Updating Firestore...');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'avatarUrl': newAvatarUrl});
      debugPrint('Firestore updated.');

      debugPrint('Evicting image from cache...');
      await CachedNetworkImage.evictFromCache(newAvatarUrl);
      debugPrint('Cache evicted.');

    } catch (e, s) {
      debugPrint('----------- ERROR UPLOADING AVATAR -----------');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $s');
      debugPrint('----------------------------------------------');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image. See logs for details.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickAndUploadImage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: widget.radius,
            backgroundColor: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                ? Colors.transparent
                : const Color(0xFF1A2C3D),
            child: ClipOval(
              child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.avatarUrl!,
                      width: widget.radius * 2,
                      height: widget.radius * 2,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        debugPrint('Error loading avatar, clearing URL: $error');
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .update({'avatarUrl': null});
                        return Icon(widget.placeholderIcon, size: widget.radius, color: Colors.white);
                      },
                    )
                  : Icon(widget.placeholderIcon, size: widget.radius, color: Colors.white),
            ),
          ),
          if (widget.editable)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 16),
              ),
            ),
          if (_isUploading)
            Container(
              width: widget.radius * 2,
              height: widget.radius * 2,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
