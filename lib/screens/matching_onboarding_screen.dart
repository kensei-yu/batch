import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatchingOnboardingScreen extends StatefulWidget {
  const MatchingOnboardingScreen({Key? key}) : super(key: key);

  @override
  _MatchingOnboardingScreenState createState() => _MatchingOnboardingScreenState();
}

class _MatchingOnboardingScreenState extends State<MatchingOnboardingScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  // フォームで選択された値を保持する変数
  String? _selectedPart;
  final List<String> _selectedGenres = [];
  final List<String> _selectedDays = [];

  // 選択肢の定義
  final List<String> _parts = ['ボーカル', 'ギター', 'ベース', 'ドラム', 'キーボード', 'その他'];
  final List<String> _genres = ['J-POP', 'ロック', 'メタル', 'パンク', 'ファンク', 'R&B', 'ヒップホップ', 'アニソン'];
  final List<String> _days = ['平日（昼）', '平日（夜）', '土日（昼）', '土日（夜）'];

  // 複数選択可能なチップを生成するヘルパーウィジェット
  Widget _buildMultiSelectChip(List<String> items, List<String> selectedItems) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: items.map((item) {
        final isSelected = selectedItems.contains(item);
        return FilterChip(
          label: Text(item),
          selected: isSelected,
          onSelected: (bool selected) {
            setState(() {
              if (selected) {
                selectedItems.add(item);
              } else {
                selectedItems.remove(item);
              }
            });
          },
          selectedColor: Theme.of(context).primaryColor.withOpacity(0.8),
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
        );
      }).toList(),
    );
  }

  Future<void> _savePreferences() async {
    if (_currentUser == null) return;
    if (_selectedPart == null || _selectedGenres.isEmpty || _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('すべての項目を選択してください。')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);

      // 回答を保存
      await userRef.collection('preferences').doc('matching').set({
        'part': _selectedPart,
        'genres': _selectedGenres,
        'days': _selectedDays,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // オンボーディングが完了したことを記録
      await userRef.update({'hasCompletedMatchingOnboarding': true});

      if (mounted) {
        Navigator.of(context).pop(true); // 成功したことを前の画面に伝える
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('設定の保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マッチング設定'),
        automaticallyImplyLeading: false, // 戻るボタンを非表示
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'あなたのことを教えてください',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'ここで設定した内容をもとに、相性の良い相手をおすすめします。',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // 担当パート
            const Text('あなたの担当パートは？', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedPart,
              items: _parts.map((part) => DropdownMenuItem(value: part, child: Text(part))).toList(),
              onChanged: (value) => setState(() => _selectedPart = value),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'パートを選択',
              ),
            ),
            const SizedBox(height: 24),

            // 好きなジャンル
            const Text('好きな音楽ジャンルは？（複数選択可）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildMultiSelectChip(_genres, _selectedGenres),
            const SizedBox(height: 24),
            
            // 活動できる曜日
            const Text('主な活動時間は？（複数選択可）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildMultiSelectChip(_days, _selectedDays),
            const SizedBox(height: 40),

            // 保存ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePreferences,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('保存して始める'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}