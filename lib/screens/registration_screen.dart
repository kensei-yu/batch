import 'dart:io'; // Fileクラスのために必要
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'home_screen.dart'; // 登録後の遷移先HomeScreen

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  File? _imageFile;
  String? _errorMessage;
  bool _isLoading = false; // 登録処理中のローディング状態

  @override
  void dispose() {
    // コントローラーを破棄
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    if (_isLoading) return; // 処理中は選択不可
    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("画像選択エラー: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "画像選択に失敗しました: $e";
        });
      }
    }
  }

  // 以前提示した _register メソッド
  Future<void> _register() async {
    // 入力値のバリデーション
    if (_nameController.text.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = '名前を入力してください。';
        });
      }
      return;
    }
    if (_emailController.text.trim().isEmpty) {
        if (mounted) {
        setState(() {
            _errorMessage = 'メールアドレスを入力してください。';
        });
        }
        return;
    }
    if (_passwordController.text.trim().isEmpty) {
        if (mounted) {
        setState(() {
            _errorMessage = 'パスワードを入力してください。';
        });
        }
        return;
    }
    // パスワードの強度チェックなどもここに追加できます

    setState(() {
      _isLoading = true; // 登録処理開始
      _errorMessage = null; // エラーメッセージをリセット
    });

    try {
      print("新規登録処理を開始します...");
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      print("Firebase Auth ユーザー作成成功: ${userCredential.user!.uid}");

      String? imageUrl;
      if (_imageFile != null) {
        print("プロフィール画像をアップロードします...");
        final storageRef = FirebaseStorage.instance
            .ref('user_images/${userCredential.user!.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg'); // ファイル名にタイムスタンプを追加して一意にする
        await storageRef.putFile(_imageFile!);
        imageUrl = await storageRef.getDownloadURL();
        print("プロフィール画像アップロード成功: $imageUrl");
      }

      print("Firestoreにユーザー情報を保存します...");
      final userData = {
        'uid': userCredential.user!.uid,
        'name': _nameController.text.trim(),
        'nickname': _nameController.text.trim(), // 初期値として名前をニックネームにも設定
        'bio': _bioController.text.trim(),
        'imageUrl': imageUrl,
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData);
      print("Firestoreへのユーザー情報保存成功。");

      // Firebase Authのユーザープロファイルも更新
      await userCredential.user!.updateDisplayName(_nameController.text.trim());
      if (imageUrl != null) {
        await userCredential.user!.updatePhotoURL(imageUrl);
      }
      print("Firebase Auth プロファイル更新完了。");

      if (mounted) {
        print("ホーム画面へ遷移します。");
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      print("FirebaseAuthException in _register: ${e.code} - ${e.message}");
      if (mounted) {
        setState(() {
          _errorMessage = '登録に失敗しました: ${e.message} (コード: ${e.code})';
        });
      }
    } catch (e) {
      print("Generic exception in _register: $e");
      if (mounted) {
        setState(() {
          _errorMessage = '予期しないエラーが発生しました: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // 登録処理終了
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新規登録'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名前 (必須)',
                  hintText: '表示される名前を入力',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: '一言紹介文 (任意)',
                  hintText: 'あなたのことを紹介してください',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.article_outlined),
                ),
                maxLines: 2,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'メールアドレス (必須)',
                  hintText: 'example@example.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'パスワード (必須)',
                  hintText: '6文字以上で入力',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 20.0),
              const Text(
                'プロフィール画像 (任意)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage:
                        _imageFile != null ? FileImage(_imageFile!) : null,
                    child: _imageFile == null
                        ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                        : null,
                  ),
                  const SizedBox(width: 16.0),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _selectImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('画像を選択'),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text('登録する'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}