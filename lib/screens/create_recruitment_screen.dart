import 'package:batch/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateRecruitmentScreen extends StatefulWidget {
  const CreateRecruitmentScreen({Key? key}) : super(key: key);

  @override
  State<CreateRecruitmentScreen> createState() => _CreateRecruitmentScreenState();
}

class _CreateRecruitmentScreenState extends State<CreateRecruitmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final List<String> _selectedInstruments = [];
  final List<String> _selectedGenres = [];
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedInstruments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('楽器を少なくとも1つ選択してください')));
      return;
    }
    if (_selectedGenres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ジャンルを少なくとも1つ選択してください')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      await FirebaseFirestore.instance.collection('recruitments').add({
        'userId': user.uid,
        'userNickname': userData?['nickname'] ?? 'Unknown',
        'userImageUrl': userData?['imageUrl'],
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'instruments': _selectedInstruments,
        'genres': _selectedGenres,
        'isRecruiting': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('募集を作成')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'タイトル',
                        hintText: '例: バンドメンバー募集！',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'タイトルを入力してください' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: '詳細',
                        hintText: '活動内容や募集要項などを詳しく書いてください',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (value) => value == null || value.isEmpty ? '詳細を入力してください' : null,
                    ),
                    const SizedBox(height: 24),
                    const Text('募集する楽器', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8.0,
                      children: AppConstants.instruments.map((instrument) {
                        final isSelected = _selectedInstruments.contains(instrument);
                        return FilterChip(
                          label: Text(instrument),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedInstruments.add(instrument);
                              } else {
                                _selectedInstruments.remove(instrument);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text('ジャンル', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8.0,
                      children: AppConstants.genres.map((genre) {
                        final isSelected = _selectedGenres.contains(genre);
                        return FilterChip(
                          label: Text(genre),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedGenres.add(genre);
                              } else {
                                _selectedGenres.remove(genre);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: const Text('募集を開始する'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
