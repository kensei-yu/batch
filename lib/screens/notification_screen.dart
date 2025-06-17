// lib/screens/notification_screen.dart
// このコードでファイル全体を置き換えてください。

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

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final notification = snapshot.data!.docs[index];
              final data = notification.data() as Map<String, dynamic>;
              final bool isRead = data['isRead'] ?? false;
              
              IconData iconData;
              Color iconColor;
              switch (data['type']) {
                case 'follow':
                  iconData = Icons.person_add;
                  iconColor = Colors.blue;
                  break;
                case 'like':
                  iconData = Icons.favorite;
                  iconColor = Theme.of(context).colorScheme.primary;
                  break;
                case 'reply':
                  iconData = Icons.comment;
                  iconColor = Colors.green;
                  break;
                default:
                  iconData = Icons.notifications;
                  iconColor = Colors.grey;
              }

              return Container(
                color: isRead ? Colors.transparent : Theme.of(context).primaryColor.withOpacity(0.05),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: iconColor.withOpacity(0.1),
                    child: Icon(iconData, color: iconColor),
                  ),
                  title: Text(data['message'] ?? '新しい通知'),
                  subtitle: Text(
                    (data['timestamp'] as Timestamp?)?.toDate().toLocal().toString().substring(0, 16) ?? '',
                  ),
                  onTap: () => _handleNotificationTap(data),
                ),
              );
            },
          );
        },
      ),
    );
  }
}