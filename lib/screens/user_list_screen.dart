import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({Key? key}) : super(key: key);

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _toggleFollow(String targetUserId) async {
    if (_currentUser == null) return;
    final currentUserId = _currentUser.uid;

    final followingRef = FirebaseFirestore.instance.collection('users').doc(currentUserId).collection('following').doc(targetUserId);
    final followerRef = FirebaseFirestore.instance.collection('users').doc(targetUserId).collection('followers').doc(currentUserId);

    final doc = await followingRef.get();

    if (doc.exists) {
      // アンフォロー
      followingRef.delete();
      followerRef.delete();
    } else {
      // フォロー
      followingRef.set({'timestamp': FieldValue.serverTimestamp()});
      followerRef.set({'timestamp': FieldValue.serverTimestamp()});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(appBar: AppBar(title: const Text('チャット相手を選択')), body: const Center(child: Text("ログインしてください")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('チャット相手を選択'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('エラー: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('ユーザーがいません'));

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userDoc = users[index];
              final userData = userDoc.data() as Map<String, dynamic>;
              final String peerUserId = userDoc.id;

              if (_currentUser!.uid == peerUserId) {
                return const SizedBox.shrink(); // 自分自身は表示しない
              }
              
              final String? imageUrl = userData['imageUrl'];

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                  child: (imageUrl == null || imageUrl.isEmpty) ? const Icon(Icons.person) : null,
                ),
                title: Text(userData['nickname'] ?? '不明なユーザー'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        peerUser: {
                          'uid': peerUserId,
                          'nickname': userData['nickname'] ?? '不明なユーザー',
                          'imageUrl': userData['imageUrl']
                        },
                      ),
                    ),
                  );
                },
                trailing: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).collection('following').doc(peerUserId).snapshots(),
                  builder: (context, snapshot) {
                    final bool isFollowing = snapshot.hasData && snapshot.data!.exists;
                    return ElevatedButton(
                      onPressed: () => _toggleFollow(peerUserId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? Colors.grey : Theme.of(context).primaryColor,
                      ),
      
                      child: Text(isFollowing ? 'フォロー中' : 'フォロー', style: const TextStyle(color: Colors.white)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}