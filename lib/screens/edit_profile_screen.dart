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
  final _formKey = GlobalKey<FormState>(); // Formキーを追加
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  String? _gender;
  DateTime? _birthDate;
  File? _imageFile;
  String? _currentImageUrl;
  bool _isSaving = false; // 保存処理中フラグ
  bool _isLoadingProfile = true; // プロフィール読み込み中フラグ

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
              _isLoadingProfile = false;
            });
          } else {
             // Firestoreにドキュメントがない場合、Authの情報で初期化
            setState(() {
              _nicknameController.text = user.displayName ?? '';
              // _currentImageUrl = user.photoURL; // AuthのphotoURLも考慮
              _isLoadingProfile = false;
            });
            print('User document does not exist, initializing with Auth data.');
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingProfile = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('プロフィール情報の読み込みに失敗しました: $e')),
          );
        }
      }
    } else {
      // ユーザーがnull (通常は発生しないはず)
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
        Navigator.of(context).pop(); // 編集画面を閉じる
      }
    }
  }

  Future<void> _selectImage() async {
    if (_isSaving) return; // 保存中は選択不可
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    if (_isSaving) return; // 保存中は選択不可
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(DateTime.now().year - 20, 1, 1), // デフォルト20年前
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ja', 'JP'), // 日本語対応
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) { // バリデーションチェック
      return;
    }
    // 必須項目のチェックはバリデーターに任せる
    // if (_gender == null) { ... }
    // if (_birthDate == null) { ... }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ユーザー情報がありません。ログインし直してください。')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      String? imageUrl = _currentImageUrl;

      if (_imageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref('user_images/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg'); // ファイル名にタイムスタンプ追加
        await storageRef.putFile(_imageFile!);
        imageUrl = await storageRef.getDownloadURL();
      }

      Map<String, dynamic> profileData = {
        'nickname': _nicknameController.text.trim(),
        'bio': _bioController.text.trim(),
        'gender': _gender,
        'birthDate': _birthDate != null ? Timestamp.fromDate(_birthDate!) : null,
        'imageUrl': imageUrl,
        'email': user.email, // emailは基本的に変更不可だが記録として
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // nameフィールドも更新または保持する場合
      // profileData['name'] = _nicknameController.text.trim(); 


      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));

      // Firebase Authのプロフィールも更新 (displayName, photoURL)
      await user.updateDisplayName(_nicknameController.text.trim());
      if (imageUrl != null) {
        await user.updatePhotoURL(imageUrl);
      }


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プロフィールを更新しました！')),
        );
        Navigator.pop(context, true); // trueを返して更新成功を通知
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('プロフィールの更新に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
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
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('保存', style: TextStyle(color: Colors.white, fontSize: 16)), // AppBarのテキスト色に合わせる
          ),
        ],
      ),
      body: Form( // Formウィジェットでラップ
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
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty
                              ? NetworkImage(_currentImageUrl!)
                              : null) as ImageProvider?,
                      child: _imageFile == null && (_currentImageUrl == null || _currentImageUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : null,
                    ),
                    Material( // InkWellのためにMaterialでラップ
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _selectImage,
                        borderRadius: BorderRadius.circular(20),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'ニックネーム (必須)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField( // TextFieldをTextFormFieldに変更
                controller: _nicknameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'ニックネームを入力',
                  counterText: "", //文字数カウンターを非表示にする場合
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
              DropdownButtonFormField<String>( // 性別選択をDropdownButtonFormFieldに変更
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
              InkWell( // TextFormFieldの代わりにInkWellを使用
                onTap: () => _selectBirthDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    // バリデーションエラーメッセージ表示のため
                    errorText: _formKey.currentState?.validate() == false && _birthDate == null
                               ? '生年月日を選択してください' : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        _birthDate != null
                            ? '${_birthDate!.year}年 ${_birthDate!.month}月 ${_birthDate!.day}日'
                            : '生年月日を選択',
                        style: TextStyle(
                          fontSize: 16,
                          color: _birthDate == null ? Colors.grey[600] : Colors.black87,
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              // 非表示のFormFieldでバリデーションを行う（オプション）
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
                // validator: (value) { /* 必要であればバリデーション */ return null; },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18)
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('保存する'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}