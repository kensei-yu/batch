// lib/screens/edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

enum ImageType { profile, header }

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  String? _gender;
  DateTime? _birthDate;
  
  // 画像関連のState
  File? _profileImageFile;
  File? _headerImageFile;
  String? _currentProfileImageUrl;
  String? _currentHeaderImageUrl;

  bool _isSaving = false;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    setState(() { _isLoadingProfile = true; });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() { _isLoadingProfile = false; });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      if (mounted && doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nicknameController.text = data['nickname'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _gender = data['gender'];
          _currentProfileImageUrl = data['imageUrl'];
          _currentHeaderImageUrl = data['headerImageUrl']; // ヘッダー画像URLを読み込む
          
          if (data['birthDate'] != null && data['birthDate'] is Timestamp) {
            _birthDate = (data['birthDate'] as Timestamp).toDate();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('プロフィール情報の読み込みに失敗しました: $e')),
        );
      }
    } finally {
      if(mounted) setState(() { _isLoadingProfile = false; });
    }
  }

  void _showImageSourceActionSheet(BuildContext context, ImageType imageType) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('写真を撮る'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera, imageType);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('アルバムから選択'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery, imageType);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source, ImageType imageType) async {
    if (_isSaving) return;
    try {
      final pickedFile = await ImagePicker().pickImage(source: source, imageQuality: 70);
      if (pickedFile != null) {
        setState(() {
          if (imageType == ImageType.profile) {
            _profileImageFile = File(pickedFile.path);
          } else {
            _headerImageFile = File(pickedFile.path);
          }
        });
      }
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像選択に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    if (_isSaving) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(DateTime.now().year - 20, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ja', 'JP'),
    );
    if (picked != null && picked != _birthDate) {
      setState(() { _birthDate = picked; });
    }
  }

  Future<String?> _uploadImageAndGetUrl(File imageFile, String folderPath) async {
    final storageRef = FirebaseStorage.instance.ref(folderPath);
    await storageRef.putFile(imageFile);
    return await storageRef.getDownloadURL();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { _isSaving = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('ユーザーが見つかりません');

      String? profileImageUrl = _currentProfileImageUrl;
      String? headerImageUrl = _currentHeaderImageUrl;

      // プロフィール画像のアップロード
      if (_profileImageFile != null) {
        profileImageUrl = await _uploadImageAndGetUrl(_profileImageFile!, 'user_images/${user.uid}/profile.jpg');
      }

      // ヘッダー画像のアップロード
      if (_headerImageFile != null) {
        headerImageUrl = await _uploadImageAndGetUrl(_headerImageFile!, 'user_images/${user.uid}/header.jpg');
      }

      Map<String, dynamic> profileData = {
        'nickname': _nicknameController.text.trim(),
        'bio': _bioController.text.trim(),
        'gender': _gender,
        'birthDate': _birthDate != null ? Timestamp.fromDate(_birthDate!) : null,
        'imageUrl': profileImageUrl,
        'headerImageUrl': headerImageUrl, // ヘッダー画像のURLを保存
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(profileData, SetOptions(merge: true));

      await user.updateDisplayName(_nicknameController.text.trim());
      if (profileImageUrl != null) {
         await user.updatePhotoURL(profileImageUrl);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('プロフィールを更新しました！')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('プロフィールの更新に失敗しました: $e')),
        );
      }
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
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('保存', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildImageHeader(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 50), // プロフィール画像との重なりを調整
                          _buildTextField(
                            controller: _nicknameController,
                            label: 'ニックネーム',
                            hint: 'ニックネームを入力',
                            maxLength: 20,
                            validator: (value) => (value == null || value.trim().isEmpty) ? 'ニックネームは必須です。' : null,
                          ),
                          const SizedBox(height: 24),
                          _buildDropdownField(
                            label: '性別',
                            value: _gender,
                            hint: '性別を選択',
                            items: ['女性', '男性', 'その他'],
                            onChanged: (value) => setState(() { _gender = value; }),
                            validator: (value) => value == null ? '性別を選択してください。' : null,
                          ),
                          const SizedBox(height: 24),
                          _buildDateField(
                            label: '生年月日',
                            value: _birthDate,
                            onTap: () => _selectBirthDate(context),
                             validator: (value) => value == null ? '生年月日を選択してください。' : null,
                          ),
                          const SizedBox(height: 24),
                           _buildTextField(
                            controller: _bioController,
                            label: '自己紹介',
                            hint: '自己紹介を入力 (任意)',
                            maxLength: 400,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImageHeader() {
    return SizedBox(
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // --- ヘッダー画像 ---
          Positioned.fill(
            child: InkWell(
              onTap: () => _showImageSourceActionSheet(context, ImageType.header),
              child: Container(
                color: Colors.grey[300],
                child: _headerImageFile != null
                    ? Image.file(_headerImageFile!, fit: BoxFit.cover)
                    : (_currentHeaderImageUrl != null && _currentHeaderImageUrl!.isNotEmpty
                        ? Image.network(_currentHeaderImageUrl!, fit: BoxFit.cover)
                        : null),
              ),
            ),
          ),
          // --- ヘッダー画像変更ボタン ---
          Center(
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.black.withOpacity(0.5),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
            ),
          ),
          // --- プロフィール画像 ---
          Positioned(
            bottom: -45, // CircleAvatarの半径分だけ下にはみ出す
            child: InkWell(
              onTap: () => _showImageSourceActionSheet(context, ImageType.profile),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor, // 背景色で縁取り
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _profileImageFile != null
                      ? FileImage(_profileImageFile!)
                      : (_currentProfileImageUrl != null && _currentProfileImageUrl!.isNotEmpty
                          ? NetworkImage(_currentProfileImageUrl!)
                          : null) as ImageProvider?,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                       if (_profileImageFile == null && (_currentProfileImageUrl == null || _currentProfileImageUrl!.isEmpty))
                          Icon(Icons.person, size: 50, color: Colors.grey[400]),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.black.withOpacity(0.5),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ],
                  )
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int? maxLength,
    int? maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        counterText: "",
        alignLabelWithHint: true,
      ),
      maxLength: maxLength,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      value: value,
      hint: Text(hint),
      items: items.map((label) => DropdownMenuItem(child: Text(label), value: label)).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    String? Function(DateTime?)? validator,
  }) {
     return FormField<DateTime>(
      initialValue: value,
      validator: (val) => validator?.call(value),
      builder: (state) {
        return InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              errorText: state.errorText,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  value != null ? DateFormat('y年M月d日').format(value) : '生年月日を選択',
                  style: TextStyle(
                    fontSize: 16,
                    color: value == null ? Colors.grey[600] : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const Icon(Icons.calendar_today_outlined, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }
}