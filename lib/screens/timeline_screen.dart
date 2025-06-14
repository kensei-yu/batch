// lib/screens/timeline_screen.dart
// このコードでファイル全体を置き換えてください。

import 'package:batch/screens/notification_screen.dart';
import 'package:batch/screens/post_detail_screen.dart';
import 'package:batch/screens/settings_screen.dart';
import 'package:batch/screens/user_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({Key? key}) : super(key: key);

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  // ... (投稿削除、いいねのロジックは変更なし)
  Future<void> _deletePost(BuildContext context, String postId) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("投稿を削除"),
        content: const Text("この投稿を削除してもよろしいですか？"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("キャンセル")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("削除", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('投稿を削除しました。')),
          );
        }
      } catch (e) {
        if (mounted) {
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

    final likeRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('liked_posts')
        .doc(postId);
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    final doc = await likeRef.get();

    if (doc.exists) {
      likeRef.delete();
      postRef.update({'likeCount': FieldValue.increment(-1)});
    } else {
      likeRef.set({'timestamp': FieldValue.serverTimestamp()});
      postRef.update({'likeCount': FieldValue.increment(1)});

      if (currentUserId != postAuthorId) {
        final notificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(postAuthorId)
            .collection('notifications')
            .doc();
        final currentUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
        final currentUserNickname =
            currentUserDoc.data()?['nickname'] ?? '誰か';

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
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            Navigator.pushNamed(context, '/settings');
          },
        ),
        title: const Text('BATCH'),
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
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final data = post.data() as Map<String, dynamic>;
              final postUserId = data['userId'] ?? '';

              if (postUserId.isEmpty) return const SizedBox.shrink();

              return _PostCard(
                post: post,
                onDelete: () => _deletePost(context, post.id),
                onToggleLike: () => _toggleLike(post.id, postUserId),
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

        return IconButton(
          icon: Badge(
            label: Text('$unreadCount'),
            isLabelVisible: unreadCount > 0,
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => const NotificationScreen())),
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  final DocumentSnapshot post;
  final VoidCallback onDelete;
  final VoidCallback onToggleLike;

  const _PostCard({
    Key? key,
    required this.post,
    required this.onDelete,
    required this.onToggleLike,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = post.data() as Map<String, dynamic>;
    final postId = post.id;
    final postUserId = data['userId'];
    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isOwner = currentUser?.uid == postUserId;

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(postUserId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return Card(
              child: Container(height: 150, color: Colors.grey[200]));
        }

        final userInfo =
            userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        final displayName = userInfo['nickname'] ?? 'ゲストユーザー';
        final String? imageUrl = userInfo['imageUrl'];
        final String userHandle = '@${userInfo['username'] ?? 'no_id'}';

        return Card(
          child: InkWell(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => PostDetailScreen(postId: postId))),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    UserProfileScreen(userId: postUserId))),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundImage: (imageUrl != null &&
                                  imageUrl.isNotEmpty)
                              ? NetworkImage(imageUrl)
                              : null,
                          child: (imageUrl == null || imageUrl.isEmpty)
                              ? const Icon(Icons.person, size: 24)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(userHandle,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                      ),
                      if (isOwner)
                        IconButton(
                            icon: const Icon(Icons.more_horiz),
                            onPressed: onDelete)
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(data['content'] ?? '',
                      style: const TextStyle(fontSize: 15, height: 1.5)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildActionButton(context,
                          icon: Icons.chat_bubble_outline,
                          count: data['commentCount'] ?? 0,
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      PostDetailScreen(postId: postId)))),
                      const SizedBox(width: 24),
                      StreamBuilder<DocumentSnapshot>(
                        stream: currentUser != null
                            ? FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser.uid)
                                .collection('liked_posts')
                                .doc(postId)
                                .snapshots()
                            : null,
                        builder: (context, likeSnapshot) {
                          final isLiked =
                              likeSnapshot.hasData && likeSnapshot.data!.exists;
                          return _buildActionButton(context,
                              icon: isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              // ▼▼▼【ここを修正】テーマカラーを使う ▼▼▼
                              color: isLiked
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                              count: data['likeCount'] ?? 0,
                              onPressed: onToggleLike);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context,
      {required IconData icon,
      Color? color,
      required int count,
      required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.grey, size: 22),
            const SizedBox(width: 8),
            Text('$count',
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}