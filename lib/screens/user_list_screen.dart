
// lib/screens/user_list_screen.dart (新規作成)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart'; // 改造後のChatScreenをインポート

class UserListScreen extends StatelessWidget {
  const UserListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('チャット相手を選択'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // usersコレクションから全ユーザーの情報を取得
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('ユーザーがいません'));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userDoc = users[index];
              final userData = userDoc.data() as Map<String, dynamic>;
              final String peerUserId = userDoc.id;

              // 自分自身は一覧に表示しない
              if (currentUser?.uid == peerUserId) {
                return const SizedBox.shrink();
              }
              
              final String? imageUrl = userData['imageUrl'];

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                      ? NetworkImage(imageUrl)
                      : null,
                  child: (imageUrl == null || imageUrl.isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(userData['nickname'] ?? '不明なユーザー'),
                onTap: () {
                  // タップしたユーザーとのチャット画面に遷移
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        // 相手のユーザー情報を渡す
                        peerUser: {
                          'uid': peerUserId,
                          'nickname': userData['nickname'] ?? '不明なユーザー',
                          'imageUrl': userData['imageUrl']
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}