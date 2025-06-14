// lib/screens/post_screen.dart
// このコードをファイル全体に貼り付けてください。

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({Key? key}) : super(key: key);

  @override
  _PostScreenState createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final TextEditingController _postController = TextEditingController();
  bool _isPosting = false;

  Future<void> _submitPost() async {
    if (_postController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿内容を入力してください。')),
      );
      return;
    }

    setState(() { _isPosting = true; });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
       setState(() { _isPosting = false; });
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'content': _postController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0,
      });

      if (mounted) {
        // 投稿成功後、結果(true)を返して画面を閉じる
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投稿に失敗しました: $e')),
        );
      }
    } finally {
      if(mounted) setState(() { _isPosting = false; });
    }
  }
  
  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ▼▼▼【レイアウトをScaffoldに変更】▼▼▼
    return Scaffold(
      appBar: AppBar(
        // 左側に閉じるボタン
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isPosting ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text('新規投稿'),
        // 右側に投稿ボタン
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton(
              onPressed: _isPosting ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                // テキストボタン風の見た目にする
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('投稿する'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: TextField(
          controller: _postController,
          autofocus: true, // 画面を開いたら自動でフォーカスする
          maxLines: null, // 複数行の入力を可能にする
          expands: true, // 利用可能なスペースいっぱいに広がる
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: '音楽の輪を広げよう',
            border: InputBorder.none, // 枠線をなくす
            filled: false, // 背景色をなくす
          ),
        ),
      ),
    );
  }
}