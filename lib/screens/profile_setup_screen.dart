import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _partController = TextEditingController();
  final _musicTastesController = TextEditingController();
  final _hobbiesController = TextEditingController();
  bool _isLoading = false;

  // 選択肢の例（必要に応じて定数ファイルなどに移動）
  final List<String> _partOptions = ['Vocal', 'Guitar', 'Bass', 'Drums', 'Keyboard', 'DJ', 'Other'];
  String? _selectedPart;

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('担当パートを選択してください')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not found');

      // カンマ区切りでリスト化
      final musicTastes = _musicTastesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final hobbies = _hobbiesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'part': _selectedPart,
        'musicTastes': musicTastes,
        'hobbies': hobbies,
        'isProfileSetupComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        // ホーム画面へ遷移（戻れないようにする）
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _partController.dispose();
    _musicTastesController.dispose();
    _hobbiesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール設定'),
        automaticallyImplyLeading: false, // 戻るボタンを非表示
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'はじめまして！\nあなたのことを教えてください。',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // 担当パート（Dropdown）
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '担当パート',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.music_note),
                ),
                value: _selectedPart,
                items: _partOptions.map((part) {
                  return DropdownMenuItem(
                    value: part,
                    child: Text(part),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPart = value;
                  });
                },
                validator: (value) => value == null ? '選択してください' : null,
              ),
              const SizedBox(height: 24),

              // 好きな音楽（TextFormField -> List）
              TextFormField(
                controller: _musicTastesController,
                decoration: const InputDecoration(
                  labelText: '好きな音楽ジャンル・アーティスト',
                  hintText: '例: Rock, Jazz, 星野源 (カンマ区切り)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.headset),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 趣味（TextFormField -> List）
              TextFormField(
                controller: _hobbiesController,
                decoration: const InputDecoration(
                  labelText: '趣味',
                  hintText: '例: 映画鑑賞, カフェ巡り (カンマ区切り)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.favorite),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('はじめる', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
