// lib/screens/registration_screen.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http; // httpパッケージをインポート
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();

  // ユーザー入力
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  
  File? _imageFile;
  DateTime? _birthDate;
  String? _selectedPrefecture;
  String? _selectedCity;
  int _age = 0;

  // APIデータと状態管理
  List<String> _prefectures = [];
  List<String> _cities = [];
  bool _isFetchingPrefectures = false;
  bool _isFetchingCities = false;

  String? _errorMessage;
  bool _isLoading = false;
  int _currentPage = 0;
  
  @override
  void initState() {
    super.initState();
    _fetchPrefectures(); // 画面初期化時に都道府県を取得
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _birthDateController.dispose();
    _pageController.dispose();
    super.dispose();
  }
  
  // --- API通信処理 ---
  Future<void> _fetchPrefectures() async {
    if (_isFetchingPrefectures) return;
    setState(() => _isFetchingPrefectures = true);
    try {
      final response = await http.get(Uri.parse('https://geoapi.heartrails.com/api/json?method=getPrefectures'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> prefs = data['response']['prefecture'];
        if (mounted) {
          setState(() => _prefectures = prefs.map((e) => e.toString()).toList());
        }
      } else {
        throw Exception('都道府県の取得に失敗しました');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'エラー: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isFetchingPrefectures = false);
    }
  }

  Future<void> _fetchCities(String prefecture) async {
    if (_isFetchingCities) return;
    setState(() {
      _isFetchingCities = true;
      _cities = []; // 市町村リストをリセット
      _selectedCity = null;
    });

    try {
      final response = await http.get(Uri.parse('https://geoapi.heartrails.com/api/json?method=getCities&prefecture=${Uri.encodeComponent(prefecture)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> locations = data['response']['location'];
        if (mounted) {
          setState(() => _cities = locations.map((loc) => loc['city'].toString()).toList());
        }
      } else {
        throw Exception('市町村の取得に失敗しました');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'エラー: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isFetchingCities = false);
    }
  }
  // --- ここまでAPI通信処理 ---

  Future<void> _selectImage() async {
    if (_isLoading) return;
    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (pickedFile != null) setState(() { _imageFile = File(pickedFile.path); });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = "画像選択に失敗しました: $e"; });
    }
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
        _birthDateController.text = DateFormat('yyyy/MM/dd').format(picked);
        _calculateAge(picked);
      });
    }
  }

  void _calculateAge(DateTime birthDate) {
    final currentDate = DateTime.now();
    int age = currentDate.year - birthDate.year;
    if (currentDate.month < birthDate.month ||
        (currentDate.month == birthDate.month && currentDate.day < birthDate.day)) {
      age--;
    }
    setState(() => _age = age);
  }
  
  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_birthDate == null || _selectedPrefecture == null || _selectedCity == null) {
      setState(() => _errorMessage = 'すべての項目を入力してください。');
      return;
    }

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
        'birthDate': _birthDate,
        'age': _age,
        'prefecture': _selectedPrefecture,
        'city': _selectedCity,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await userCredential.user!.updateDisplayName(_nameController.text.trim());
      if (imageUrl != null) await userCredential.user!.updatePhotoURL(imageUrl);

    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { 
        _errorMessage = e.code == 'email-already-in-use' 
          ? 'このメールアドレスは既に使用されています。'
          : '登録エラー: ${e.message}';
      });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = '予期しないエラーが発生しました。'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('新規登録 (${_currentPage + 1}/3)'),
        leading: _currentPage > 0 
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _previousPage)
          : null,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.PNG'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black38, BlendMode.darken),
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              LinearProgressIndicator(value: (_currentPage + 1) / 3),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildProfilePage(),
                    _buildBirthDatePage(),
                    _buildLocationPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
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
              if (value == null || value.trim().isEmpty) return 'ユーザーIDを入力してください';
              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) return 'ユーザーIDは英数字とアンダースコア(_)のみ使用できます';
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
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text('次へ'),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthDatePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('生年月日を教えてください', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          TextFormField(
            controller: _birthDateController,
            decoration: const InputDecoration(labelText: '生年月日', prefixIcon: Icon(Icons.cake_outlined)),
            readOnly: true,
            onTap: () => _selectBirthDate(context),
            validator: (value) => (value == null || value.isEmpty) ? '生年月日を選択してください' : null,
          ),
          const SizedBox(height: 24.0),
          if (_age > 0)
            Text('年齢: $_age 歳', style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: 32.0),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text('次へ'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('お住まいの地域を教えてください', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          // 都道府県選択
          DropdownButtonFormField<String>(
            value: _selectedPrefecture,
            hint: _isFetchingPrefectures ? const Text('読み込み中...') : const Text('都道府県を選択'),
            isExpanded: true,
            items: _prefectures.map((String prefecture) {
              return DropdownMenuItem<String>(
                value: prefecture,
                child: Text(prefecture),
              );
            }).toList(),
            onChanged: _isFetchingPrefectures ? null : (newValue) {
              if (newValue != null) {
                setState(() => _selectedPrefecture = newValue);
                _fetchCities(newValue);
              }
            },
            validator: (value) => value == null ? '都道府県を選択してください' : null,
          ),
          const SizedBox(height: 16.0),

          // 市町村選択
          DropdownButtonFormField<String>(
            value: _selectedCity,
            hint: _isFetchingCities ? const Text('読み込み中...') : const Text('市町村を選択'),
            isExpanded: true,
            items: _cities.map((String city) {
              return DropdownMenuItem<String>(
                value: city,
                child: Text(city),
              );
            }).toList(),
            onChanged: (_selectedPrefecture == null || _isFetchingCities) ? null : (newValue) {
              setState(() => _selectedCity = newValue);
            },
            validator: (value) => value == null ? '市町村を選択してください' : null,
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
    );
  }
}