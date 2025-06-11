// lib/screens/post_screen.dart

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

    setState(() {
      _isPosting = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
       setState(() {
        _isPosting = false;
      });
      // エラー処理: ユーザーがログインしていない
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'content': _postController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'likeCount': 0, // この行を修正（追加）
        // 'userName': user.displayName, // 必要であればユーザー名も保存
        // 'userImage': user.photoURL,   // 必要であればユーザー画像URLも保存
      });

      if (mounted) {
        Navigator.of(context).pop(true); // trueを返して成功を通知
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投稿に失敗しました: $e')),
        );
      }
    } finally {
      if(mounted){
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // MediaQueryを使用して画面の高さを取得し、モーダルの高さを調整
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      // viewInsets.bottom はキーボードの高さを考慮
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        height: mediaQuery.size.height * 0.5, //画面の50%程度の高さ
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // コンテンツに合わせて高さを調整
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _isPosting ? null : () { // 投稿中は無効化
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  onPressed: _isPosting ? null : _submitPost, // 投稿中は無効化
                  child: _isPosting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('投稿'),
                ),
              ],
            ),
            const SizedBox(height: 10), // 少し間隔を調整
            Expanded( // TextFieldが利用可能なスペースを全て使うようにする
              child: TextField(
                controller: _postController,
                maxLines: null, // 自動で複数行になるように
                expands: true, // 利用可能なスペースいっぱいに広がる
                textAlignVertical: TextAlignVertical.top, // テキストを上寄せに
                decoration: const InputDecoration(
                  hintText: 'メンバーを募集しよう',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}