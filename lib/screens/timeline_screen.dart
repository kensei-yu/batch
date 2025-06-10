import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({Key? key}) : super(key: key);

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

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

  Future<void> _toggleLike(String postId, int currentLikeCount) async {
    if (_currentUser == null) return;
    final currentUserId = _currentUser.uid;
    
    final likeRef = FirebaseFirestore.instance.collection('users').doc(currentUserId).collection('liked_posts').doc(postId);
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    final doc = await likeRef.get();

    if (doc.exists) {
      // いいね解除
      likeRef.delete();
      postRef.update({'likeCount': FieldValue.increment(-1)});
    } else {
      // いいねする
      likeRef.set({'timestamp': FieldValue.serverTimestamp()});
      postRef.update({'likeCount': FieldValue.increment(1)});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BATCH'),
        automaticallyImplyLeading: false,
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
              final String postUserId = data['userId'];
              final bool isOwner = _currentUser?.uid == postUserId;
              final int likeCount = data['likeCount'] ?? 0;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(postUserId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const Card(
                      child: ListTile(title: Text("読み込み中..."))
                    );
                  }
                  
                  final userInfo = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                  final displayName = userInfo['nickname'] ?? 'ゲストユーザー';
                  final String? imageUrl = userInfo['imageUrl'];

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                                child: (imageUrl == null || imageUrl.isEmpty) ? const Icon(Icons.person, size: 24) : null,
                              ),
                              const SizedBox(width: 10),
                              Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              if (isOwner)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.grey),
                                  onPressed: () => _deletePost(context, postId),
                                )
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                            child: Text(data['content'] ?? ''),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              StreamBuilder<DocumentSnapshot>(
                                stream: _currentUser != null ? FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).collection('liked_posts').doc(postId).snapshots() : null,
                                builder: (context, likeSnapshot) {
                                  final bool isLiked = likeSnapshot.hasData && likeSnapshot.data!.exists;
                                  return IconButton(
                                    icon: Icon(
                                      isLiked ? Icons.favorite : Icons.favorite_border,
                                      color: isLiked ? Colors.red : Colors.grey,
                                    ),
                                    onPressed: () => _toggleLike(postId, likeCount),
                                  );
                                },
                              ),
                              Text('$likeCount'),
                            ],
                          ),
                        ],
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