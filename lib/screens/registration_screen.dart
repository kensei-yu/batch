// lib/screens/registration_screen.dart
// このコードをファイル全体に貼り付けてください。

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  File? _imageFile;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    if (_isLoading) return;
    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (pickedFile != null) setState(() { _imageFile = File(pickedFile.path); });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = "画像選択に失敗しました: $e"; });
    }
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      String? imageUrl;
      if (_imageFile != null) {
        final storageRef = FirebaseStorage.instance.ref('user_images/${userCredential.user!.uid}/profile.jpg');
        await storageRef.putFile(_imageFile!);
        imageUrl = await storageRef.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'nickname': _nameController.text.trim(),
        'username': _usernameController.text.trim().toLowerCase(),
        'bio': '',
        'imageUrl': imageUrl,
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await userCredential.user!.updateDisplayName(_nameController.text.trim());
      if (imageUrl != null) await userCredential.user!.updatePhotoURL(imageUrl);

      // ▼▼▼【修正点】新規登録後の画面遷移命令を削除 ▼▼▼
      // AuthGateが遷移をハンドルするため、ここでは不要です。
      // if (mounted) {
      //   Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      // }

    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { 
        if (e.code == 'email-already-in-use') {
          _errorMessage = 'このメールアドレスは既に使用されています。';
        } else {
          _errorMessage = '登録エラー: ${e.message}';
        }
      });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = '予期しないエラーが発生しました。'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規登録')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('BATCHへようこそ！', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('まずはプロフィールを登録しましょう', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  ),

                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                        child: _imageFile == null ? Icon(Icons.person, size: 50, color: Colors.grey[400]) : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                            onPressed: _selectImage,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'ニックネーム', prefixIcon: Icon(Icons.person_outline)),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'ニックネームを入力してください' : null,
                ),
                const SizedBox(height: 16.0),

                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'ユーザーID (@無し・英数字と_のみ)', hintText: '例: your_id', prefixIcon: Icon(Icons.alternate_email)),
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
                const SizedBox(height: 16.0),

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'メールアドレス', prefixIcon: Icon(Icons.email_outlined)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => (value == null || !value.contains('@')) ? '有効なメールアドレスを入力してください' : null,
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'パスワード (6文字以上)', prefixIcon: Icon(Icons.lock_outline)),
                  obscureText: true,
                  validator: (value) => (value == null || value.length < 6) ? '6文字以上のパスワードを入力してください' : null,
                ),
                const SizedBox(height: 32.0),
                _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _register,
                      child: const Text('同意して登録する'),
                    ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    '登録することにより、利用規約とプライバシーポリシーに同意したことになります。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
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