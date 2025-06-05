import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({Key? key}) : super(key: key);

  Future<void> _deletePost(BuildContext context, String postId) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("投稿を削除"),
        content: const Text("この投稿を削除してもよろしいですか？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("キャンセル")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("削除", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
        if(context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('投稿を削除しました。')),
          );
        }
      } catch (e) {
        if(context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('投稿の削除に失敗しました: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BATCH'), // アプリ名
        automaticallyImplyLeading: false, // HomeScreenで管理するため不要
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('投稿がありません'));
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final data = post.data() as Map<String, dynamic>;
              final postId = post.id;
              final String postUserId = data['userId']; //投稿者のUID
              final bool isOwner = currentUser?.uid == postUserId;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(postUserId) //投稿者のUIDを使用
                    .get(),
                builder: (context, userSnapshot) {
                  // ローディング中の表示 (任意)
                  // if (userSnapshot.connectionState == ConnectionState.waiting) {
                  //   return const Card(child: ListTile(title: Text("ユーザー情報読み込み中...")));
                  // }

                  if (userSnapshot.hasError) {
                    // ユーザー情報取得エラーの場合の表示
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.error)),
                        title: const Text('ユーザー情報取得エラー', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        subtitle: Text(data['content'] ?? ''),
                        trailing: isOwner
                            ? IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deletePost(context, postId),
                              )
                            : null,
                      ),
                    );
                  }
                  
                  // ユーザー情報が存在しない場合のフォールバック
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                     return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                        title: const Text('不明なユーザー', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(data['content'] ?? ''),
                        trailing: isOwner
                            ? IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deletePost(context, postId),
                              )
                            : null,
                      ),
                    );
                  }

                  final userInfo = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                  
                  // 表示名: nicknameがあればそれを、なければname、それもなければ「ゲストユーザー」
                  final displayName = userInfo['nickname']?.toString().isNotEmpty == true
                      ? userInfo['nickname']
                      : (userInfo['name']?.toString().isNotEmpty == true 
                          ? userInfo['name'] 
                          : 'ゲストユーザー');
                  
                  // プロフィール画像のURL
                  final String? imageUrl = userInfo['imageUrl'] as String?;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                            ? NetworkImage(imageUrl)
                            : null, // nullの場合、childが表示される
                        // 画像がない場合のフォールバックアイコン
                        child: (imageUrl == null || imageUrl.isEmpty)
                            ? const Icon(Icons.person, size: 24) 
                            : null,
                      ),
                      title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Padding( // 投稿内容の上に少しマージン
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(data['content'] ?? ''),
                      ),
                      trailing: isOwner
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deletePost(context, postId),
                            )
                          : null,
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