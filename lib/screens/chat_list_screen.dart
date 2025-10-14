// lib/screens/chat_list_screen.dart

import 'package:batch/screens/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('メッセージ')),
        body: const Center(child: Text("メッセージ機能を利用するにはログインが必要です。")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('メッセージ'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .where('userIds', arrayContains: _currentUser!.uid)
            .orderBy('lastUpdatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (snapshot.error.toString().contains('INDEX_NOT_FOUND') || snapshot.error.toString().contains('requires an index')) {
               return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'データベースの設定が必要です。\n開発コンソールの指示に従って、複合インデックスを作成してください。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('チャット履歴がありません'));
          }

          final chatDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chatDocs.length,
            itemBuilder: (context, index) {
              final chatDoc = chatDocs[index];
              final data = chatDoc.data() as Map<String, dynamic>;
              final List<dynamic> userIds = data['userIds'];
              
              final peerId = userIds.firstWhere((id) => id != _currentUser!.uid, orElse: () => null);
              
              if (peerId == null) return const SizedBox.shrink();

              final unreadCount = data['unreadCount_${_currentUser!.uid}'] ?? 0;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(peerId).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                     return const ListTile(title: Text("読み込み中..."));
                  }
                  
                  Map<String, dynamic> peerUser = {};
                  String nickname = '不明なユーザー';
                  String? peerImageUrl;

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    peerUser = userSnapshot.data!.data() as Map<String, dynamic>;
                    nickname = peerUser['nickname'] ?? '不明なユーザー';
                    peerImageUrl = peerUser['imageUrl'];
                  }
                  
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: peerImageUrl != null ? NetworkImage(peerImageUrl) : null,
                      child: peerImageUrl == null 
                          ? const Icon(Icons.person, color: Colors.white) 
                          : null,
                    ),
                    title: Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      data['lastMessage'] ?? 'まだメッセージはありません',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: unreadCount > 0 
                      ? Badge(
                          label: Text('$unreadCount'),
                        ) 
                      : null,
                    onTap: () {
                      final Map<String, dynamic> peerUserDataForChat = {
                        'uid': peerId,
                        'nickname': nickname,
                        'imageUrl': peerImageUrl,
                      };
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(peerUser: peerUserDataForChat),
                        ),
                      );
                    },
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

