import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile_screen.dart';
import 'post_detail_screen.dart';
import 'notification_screen.dart'; // 通知画面をインポート

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

  Future<void> _toggleLike(String postId, String postAuthorId) async {
    if (_currentUser == null) return;
    final currentUserId = _currentUser!.uid;
    
    final likeRef = FirebaseFirestore.instance.collection('users').doc(currentUserId).collection('liked_posts').doc(postId);
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    final doc = await likeRef.get();

    if (doc.exists) {
      likeRef.delete();
      postRef.update({'likeCount': FieldValue.increment(-1)});
    } else {
      likeRef.set({'timestamp': FieldValue.serverTimestamp()});
      postRef.update({'likeCount': FieldValue.increment(1)});

      // 自分の投稿でなければ通知を作成
      if (currentUserId != postAuthorId) {
        final notificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(postAuthorId) // 投稿者のID
            .collection('notifications')
            .doc(); // 新しいドキュメントIDを自動生成

        final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
        final currentUserNickname = currentUserDoc.data()?['nickname'] ?? '誰か';

        await notificationRef.set({
          'id': notificationRef.id,
          'type': 'like',
          'senderId': currentUserId,
          'message': '$currentUserNickname さんがあなたの投稿に「いいね」しました。',
          'postId': postId,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BATCH'),
        automaticallyImplyLeading: false,
        actions: [
          _buildNotificationButton(context),
        ],
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
              
              final dynamic postUserIdValue = data['userId'];

              if (postUserIdValue == null || postUserIdValue is! String) {
                return const SizedBox.shrink();
              }
              
              final String postUserId = postUserIdValue;
              final bool isOwner = _currentUser?.uid == postUserId;
              final int likeCount = data['likeCount'] ?? 0;
              final int commentCount = data['commentCount'] ?? 0;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(postUserId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const Card(child: ListTile(title: Text("読み込み中...")));
                  }
                  
                  final userInfo = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                  final displayName = userInfo['nickname'] ?? 'ゲストユーザー';
                  final String? imageUrl = userInfo['imageUrl'];

                  return Card(
                    elevation: 2.0,
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) => UserProfileScreen(userId: postUserId),
                              ));
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                                  child: (imageUrl == null || imageUrl.isEmpty) ? const Icon(Icons.person, size: 22) : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      if(data['timestamp'] != null)
                                        Text(
                                          (data['timestamp'] as Timestamp).toDate().toLocal().toString().substring(0, 16),
                                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isOwner)
                                  IconButton(
                                    icon: const Icon(Icons.more_horiz),
                                    onPressed: () => _deletePost(context, postId),
                                  )
                              ],
                            ),
                          ),
                          const Divider(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(data['content'] ?? '', style: const TextStyle(fontSize: 15, height: 1.4)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              StreamBuilder<DocumentSnapshot>(
                                stream: _currentUser != null ? FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).collection('liked_posts').doc(postId).snapshots() : null,
                                builder: (context, likeSnapshot) {
                                  final bool isLiked = likeSnapshot.hasData && likeSnapshot.data!.exists;
                                  return IconButton(
                                    icon: Icon(
                                      isLiked ? Icons.favorite : Icons.favorite_border,
                                      color: isLiked ? Colors.red : Colors.grey,
                                    ),
                                    onPressed: () => _toggleLike(postId, postUserId),
                                  );
                                },
                              ),
                              Text('$likeCount', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline, color: Colors.grey),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PostDetailScreen(postId: postId),
                                    ),
                                  );
                                },
                              ),
                              Text('$commentCount', style: const TextStyle(color: Colors.grey, fontSize: 14)),
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

  Widget _buildNotificationButton(BuildContext context) {
    if (_currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationScreen()),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
