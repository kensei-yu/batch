// lib/screens/edit_profile_screen.dart
// このコードをファイル全体に貼り付けてください。

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  File? _profileImageFile;
  File? _headerImageFile;
  String? _currentProfileImageUrl;
  String? _currentHeaderImageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }
  
  @override
  void dispose() {
    _nicknameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (mounted && doc.exists) {
      final data = doc.data()!;
      setState(() {
        _nicknameController.text = data['nickname'] ?? '';
        _usernameController.text = data['username'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _currentProfileImageUrl = data['imageUrl'];
        _currentHeaderImageUrl = data['headerImageUrl'];
      });
    }
  }

  Future<void> _pickImage(ImageSource source, bool isProfile) async {
    if (_isSaving) return;
    final pickedFile = await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        if (isProfile) _profileImageFile = File(pickedFile.path);
        else _headerImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isSaving = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('ユーザーが見つかりません');

      // 重要：ここでもユーザーIDの重複チェックが必要です

      String? profileImageUrl = _currentProfileImageUrl;
      if (_profileImageFile != null) {
        final ref = FirebaseStorage.instance.ref('user_images/${user.uid}/profile.jpg');
        await ref.putFile(_profileImageFile!);
        profileImageUrl = await ref.getDownloadURL();
      }

      String? headerImageUrl = _currentHeaderImageUrl;
      if (_headerImageFile != null) {
        final ref = FirebaseStorage.instance.ref('user_images/${user.uid}/header.jpg');
        await ref.putFile(_headerImageFile!);
        headerImageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'nickname': _nicknameController.text.trim(),
        'username': _usernameController.text.trim().toLowerCase(),
        'bio': _bioController.text.trim(),
        'imageUrl': profileImageUrl,
        'headerImageUrl': headerImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await user.updateDisplayName(_nicknameController.text.trim());
      if (profileImageUrl != null) await user.updatePhotoURL(profileImageUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('プロフィールを更新しました！')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('プロフィールの更新に失敗しました: $e')));
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール編集'),
        actions: [
          _isSaving
            ? const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)))
            : TextButton(
                onPressed: _saveProfile,
                child: const Text('保存', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildImageEditors(),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nicknameController,
                      decoration: const InputDecoration(labelText: 'ニックネーム', prefixIcon: Icon(Icons.person_outline)),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'ニックネームは必須です' : null,
                    ),
                    const SizedBox(height: 24),
                    
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'ユーザーID', prefixIcon: Icon(Icons.alternate_email)),
                      validator: (value) {
                         if (value == null || value.trim().isEmpty) {
                           return 'ユーザーIDを入力してください';
                         }
                         final pattern = r'^[a-zA-Z0-9_]+$';
                         final regExp = RegExp(pattern);
                         if (!regExp.hasMatch(value)) {
                           return 'ユーザーIDは英数字とアンダースコア(_)のみ使用できます';
                         }
                         return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(labelText: '自己紹介', alignLabelWithHint: true, prefixIcon: Icon(Icons.edit_note_outlined)),
                      maxLines: 4,
                      maxLength: 200,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageEditors() {
    final headerImage = _headerImageFile != null
        ? FileImage(_headerImageFile!)
        : (_currentHeaderImageUrl != null && _currentHeaderImageUrl!.isNotEmpty
            ? NetworkImage(_currentHeaderImageUrl!)
            : null) as ImageProvider?;

    final profileImage = _profileImageFile != null
        ? FileImage(_profileImageFile!)
        : (_currentProfileImageUrl != null && _currentProfileImageUrl!.isNotEmpty
            ? NetworkImage(_currentProfileImageUrl!)
            : null) as ImageProvider?;

    return SizedBox(
      height: 220,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          InkWell(
            onTap: () => _pickImage(ImageSource.gallery, false),
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                image: headerImage != null ? DecorationImage(image: headerImage, fit: BoxFit.cover) : null,
              ),
              child: Center(child: Icon(Icons.camera_alt_outlined, color: Colors.white.withOpacity(0.7), size: 32)),
            ),
          ),
          Positioned(
            bottom: 0,
            child: InkWell(
              onTap: () => _pickImage(ImageSource.gallery, true),
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: profileImage,
                  child: profileImage == null ? Icon(Icons.person, size: 50, color: Colors.grey[400]) : Center(child: Icon(Icons.camera_alt_outlined, color: Colors.white.withOpacity(0.7), size: 32)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}