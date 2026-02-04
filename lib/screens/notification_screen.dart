// lib/screens/notification_screen.dart


import 'package:batch/screens/chat_screen.dart'; // Import added
import 'package:batch/screens/post_detail_screen.dart';
import 'package:batch/screens/user_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // ▼▼▼【追加】画面が表示された時に未読通知を既読にする ▼▼▼
    if (_currentUser != null) {
      _markAllAsRead();
    }
  }

  // ▼▼▼【追加】未読の通知を全て既読にするメソッド ▼▼▼
  Future<void> _markAllAsRead() async {
    final notificationsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('notifications');

    // isReadがfalseのドキュメントを取得
    final unreadNotifications = await notificationsRef.where('isRead', isEqualTo: false).get();

    // トランザクションやバッチ書き込みで一括更新
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unreadNotifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // 通知タップ時の画面遷移処理
  void _handleNotificationTap(Map<String, dynamic> notificationData) {
    final String type = notificationData['type'];

    switch (type) {
      case 'follow':
        Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: notificationData['senderId'])));
        break;
      case 'like':
      case 'reply':
        final postId = notificationData['postId'];
        if (postId != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)));
        }
        break;
      case 'message':
        final senderId = notificationData['senderId'];
        if (senderId != null) {
          FirebaseFirestore.instance.collection('users').doc(senderId).get().then((doc) {
             if (doc.exists && mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(peerUser: {
                  'uid': doc.id,
                  'nickname': doc.data()?['nickname'] ?? '不明なユーザー',
                  'imageUrl': doc.data()?['imageUrl'],
                })));
             }
          });
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('通知')),
        body: const Center(child: Text("通知機能を利用するにはログインが必要です。")),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('通知はありません'));

          return ListView.separated(
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = snapshot.data!.docs[index];
              final data = notification.data() as Map<String, dynamic>;
              return _TwitterNotificationTile(
                data: data,
                onTap: () => _handleNotificationTap(data),
              );
            },
          );
        },
      ),
    );
  }
}

class _TwitterNotificationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _TwitterNotificationTile({
    Key? key,
    required this.data,
    required this.onTap,
  }) : super(key: key);

  Future<Map<String, dynamic>> _fetchData() async {
    final Map<String, dynamic> result = {};
    
    // Fetch User
    if (data['senderId'] != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(data['senderId']).get();
      result['user'] = userDoc.exists ? userDoc.data() : null;
    }

    // Fetch Content if missing and type is like
    if ((data['content'] == null || data['content'].toString().isEmpty) && data['type'] == 'like' && data['postId'] != null) {
       final postDoc = await FirebaseFirestore.instance.collection('posts').doc(data['postId']).get();
       if (postDoc.exists) {
         result['content'] = (postDoc.data() as Map<String, dynamic>)['content'];
       }
    } else {
       result['content'] = data['content'];
    }
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final String type = data['type'];
    final bool isRead = data['isRead'] ?? false;
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;

    IconData iconData;
    Color iconColor;
    String actionText = "";

    switch (type) {
      case 'follow':
        iconData = Icons.person;
        iconColor = Colors.blue;
        actionText = "あなたをフォローしました";
        break;
      case 'like':
        iconData = Icons.favorite;
        iconColor = Colors.pink;
        actionText = "あなたの投稿にいいねしました";
        break;
      case 'reply':
        iconData = Icons.chat_bubble; 
        iconColor = Colors.blueGrey; 
        actionText = "あなたの投稿に返信しました";
        break;
      case 'message':
        iconData = Icons.mail;
        iconColor = Colors.orange;
        actionText = "メッセージが届きました";
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    // Time Ago
    String timeAgo = '';
    if (timestamp != null) {
        final diff = DateTime.now().difference(timestamp.toDate());
        if (diff.inMinutes < 60) {
            timeAgo = '${diff.inMinutes}分前';
        } else if (diff.inHours < 24) {
             timeAgo = '${diff.inHours}時間前';
        } else {
             final date = timestamp.toDate();
             timeAgo = '${date.month}/${date.day}';
        }
    }

    return InkWell(
      onTap: onTap,
      child: Container(
         color: isRead ? Colors.transparent : Theme.of(context).primaryColor.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Icon
            SizedBox(
              width: 30,
              child: Align(
                alignment: Alignment.topRight,
                child: Icon(iconData, color: iconColor, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            // Right Content
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _fetchData(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  
                  final user = snapshot.data?['user'] as Map<String, dynamic>? ?? {};
                  final userImage = user['imageUrl'] as String?;
                  final content = snapshot.data?['content'] as String?;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: userImage != null ? NetworkImage(userImage) : null,
                            backgroundColor: Colors.grey.shade300,
                            child: userImage == null ? const Icon(Icons.person, size: 14, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  actionText, 
                                  style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color)
                              ),
                          ),
                          const SizedBox(width: 4),
                          Text(timeAgo, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                        ],
                      ),
                      if (content != null && content.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                            content,
                            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8), fontSize: 14),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}