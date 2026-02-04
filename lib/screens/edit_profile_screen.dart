// lib/screens/edit_profile_screen.dart


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

  // ▼▼▼【ここから修正】ロード中フラグを追加 ▼▼▼
  bool _isLoading = true; // 初期状態はロード中
  String _initialNickname = '';
  String _initialUsername = '';
  String _initialBio = '';

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
    // 既に _isLoading = true で初期化しているのでここで再度セットする必要はないが、
    // 再読み込みなどを考慮するなら setState(() { _isLoading = true; }); してもよい
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted && doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nicknameController.text = data['nickname'] ?? '';
          _usernameController.text = data['username'] ?? '';
          _bioController.text = data['bio'] ?? '';
          
          _initialNickname = _nicknameController.text;
          _initialUsername = _usernameController.text;
          _initialBio = _bioController.text;
          _currentProfileImageUrl = data['imageUrl'];
          _currentHeaderImageUrl = data['headerImageUrl'];
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // ロード完了
        });
      }
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

  // ▼▼▼【ここから修正】Storageへ画像をアップロードする処理に変更 ▼▼▼
  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isSaving = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('ユーザーが見つかりません');

      final Map<String, dynamic> dataToUpdate = {};

      // テキストフィールドの変更をチェック
      final newNickname = _nicknameController.text.trim();
      final newUsername = _usernameController.text.trim().toLowerCase();
      final newBio = _bioController.text.trim();

      if (newNickname != _initialNickname) dataToUpdate['nickname'] = newNickname;
      if (newUsername != _initialUsername) dataToUpdate['username'] = newUsername;
      if (newBio != _initialBio) dataToUpdate['bio'] = newBio;
      
      // プロフィール画像の変更をチェック
      if (_profileImageFile != null) {
        final ref = FirebaseStorage.instance.ref('user_images/${user.uid}/profile.jpg');
        await ref.putFile(_profileImageFile!, SettableMetadata(contentType: 'image/jpeg'));
        final url = await ref.getDownloadURL();
        final separator = url.contains('?') ? '&' : '?';
        dataToUpdate['imageUrl'] = '$url${separator}v=${DateTime.now().millisecondsSinceEpoch}';
      }

      // ヘッダー画像の変更をチェック
      if (_headerImageFile != null) {
        final ref = FirebaseStorage.instance.ref('user_images/${user.uid}/header.jpg');
        await ref.putFile(_headerImageFile!, SettableMetadata(contentType: 'image/jpeg'));
        final url = await ref.getDownloadURL();
        final separator = url.contains('?') ? '&' : '?';
        dataToUpdate['headerImageUrl'] = '$url${separator}v=${DateTime.now().millisecondsSinceEpoch}';
      }

      // 更新するデータが何か一つでもあれば、DBに書き込む
      if (dataToUpdate.isNotEmpty) {
        dataToUpdate['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update(dataToUpdate);
      }

      // ニックネームが変更されていたら、Authの表示名も更新
      if (dataToUpdate.containsKey('nickname')) {
        await user.updateDisplayName(newNickname);
      }
      // プロフィール画像が変更されていたら、AuthのphotoURLも更新
      if (dataToUpdate.containsKey('imageUrl')) {
        await user.updatePhotoURL(dataToUpdate['imageUrl']);
      }

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

  // Base64関連の処理は不要になったので、シンプルなヘルパーに変更
  ImageProvider? _getImageProvider(File? file, String? url) {
    if (file != null) return FileImage(file);
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return null;
  }
  // ▲▲▲【ここまで修正】▲▲▲

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
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
    final headerImage = _getImageProvider(_headerImageFile, _currentHeaderImageUrl);
    final profileImage = _getImageProvider(_profileImageFile, _currentProfileImageUrl);

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
              child: headerImage == null ? Center(child: Icon(Icons.camera_alt_outlined, color: Colors.white.withOpacity(0.7), size: 32)) : null,
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