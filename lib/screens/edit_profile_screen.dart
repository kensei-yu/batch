// lib/screens/edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // DateFormatのためにインポート

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
  File? _imageFile;
  String? _currentImageUrl;
  bool _isSaving = false;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    setState(() {
      _isLoadingProfile = true;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (mounted) {
          if (doc.exists) {
            final data = doc.data()!;
            setState(() {
              _nicknameController.text = data['nickname'] ?? data['name'] ?? user.displayName ?? '';
              _bioController.text = data['bio'] ?? '';
              _gender = data['gender'];
              _currentImageUrl = data['imageUrl'];
              
              if (data['birthDate'] != null && data['birthDate'] is Timestamp) {
                _birthDate = (data['birthDate'] as Timestamp).toDate();
              }
            });
          } else {
            setState(() {
              _nicknameController.text = user.displayName ?? '';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('プロフィール情報の読み込みに失敗しました: $e')),
          );
        }
      } finally {
        if(mounted) {
          setState(() {
            _isLoadingProfile = false;
          });
        }
      }
    }
  }

  /// 画像の取得方法を選択するシートを表示する
  void _showImageSourceActionSheet(BuildContext context) {
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
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('アルバムから選択'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_currentImageUrl != null || _imageFile != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('画像を削除', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _removeImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// ImagePickerを使って画像を選択する
  Future<void> _pickImage(ImageSource source) async {
    if (_isSaving) return;
    try {
      final pickedFile = await ImagePicker().pickImage(source: source, imageQuality: 70);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch(e) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像選択に失敗しました: $e')),
      );
    }
  }

  /// 画像を削除する
  void _removeImage() {
    setState(() {
      _imageFile = null;
      _currentImageUrl = null;
    });
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
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() { _isSaving = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('ユーザーが見つかりません');
      }

      String? imageUrl = _currentImageUrl;

      // 新しい画像ファイルがある場合、アップロードしてURLを取得
      if (_imageFile != null) {
        final storageRef = FirebaseStorage.instance.ref('user_images/${user.uid}/profile.jpg'); // ファイル名を固定して上書き
        await storageRef.putFile(_imageFile!);
        imageUrl = await storageRef.getDownloadURL();
      } else if (_currentImageUrl == null) {
        // 画像が削除された場合
        imageUrl = null;
      }

      Map<String, dynamic> profileData = {
        'nickname': _nicknameController.text.trim(),
        'bio': _bioController.text.trim(),
        'gender': _gender,
        'birthDate': _birthDate != null ? Timestamp.fromDate(_birthDate!) : null,
        'imageUrl': imageUrl, // 更新されたURLまたはnullをセット
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));

      await user.updateDisplayName(_nicknameController.text.trim());
      await user.updatePhotoURL(imageUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プロフィールを更新しました！')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('プロフィールの更新に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }
  
  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Scaffold(
        appBar: AppBar(title: const Text('プロフィール編集')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール編集'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),)
                : const Text('保存', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'プロフィール画像',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Center(
                child: InkWell(
                  onTap: () => _showImageSourceActionSheet(context),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty
                                ? NetworkImage(_currentImageUrl!)
                                : null) as ImageProvider?,
                        child: _imageFile == null && (_currentImageUrl == null || _currentImageUrl!.isEmpty)
                            ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                            : null,
                      ),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'ニックネーム (必須)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'ニックネームを入力',
                  counterText: "",
                ),
                maxLength: 20,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'ニックネームは必須です。';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                '性別 (必須)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '性別を選択',
                ),
                value: _gender,
                items: ['女性', '男性', 'その他']
                    .map((label) => DropdownMenuItem(
                          child: Text(label),
                          value: label,
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _gender = value;
                  });
                },
                validator: (value) => value == null ? '性別を選択してください。' : null,
              ),
              const SizedBox(height: 24),

              const Text(
                '生年月日 (必須)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectBirthDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    errorText: _formKey.currentState?.validate() == false && _birthDate == null
                               ? '生年月日を選択してください' : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        _birthDate != null
                            ? DateFormat('y年M月d日').format(_birthDate!)
                            : '生年月日を選択',
                        style: TextStyle(
                          fontSize: 16,
                          color: _birthDate == null ? Colors.grey[600] : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              FormField<DateTime>(
                builder: (state) => const SizedBox.shrink(),
                validator: (value) {
                  if (_birthDate == null) return '生年月日を選択してください。';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              const Text(
                '自己紹介',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '自己紹介を入力 (任意)',
                  counterText: "",
                ),
                maxLength: 400,
                maxLines: 4,
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}