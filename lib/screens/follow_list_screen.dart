import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile_screen.dart';

class FollowListScreen extends StatelessWidget {
  final String userId;
  final String listType; // "following" または "followers"

  const FollowListScreen({
    Key? key,
    required this.userId,
    required this.listType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(listType == 'following' ? 'フォロー中' : 'フォロワー'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection(listType)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text(listType == 'following' ? '誰もフォローしていません。' : 'フォロワーがいません。'));
          }

          final userIds = snapshot.data!.docs.map((doc) => doc.id).toList();

          return ListView.builder(
            itemCount: userIds.length,
            itemBuilder: (context, index) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(userIds[index]).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final String? imageUrl = userData['imageUrl'];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                      child: (imageUrl == null || imageUrl.isEmpty) ? const Icon(Icons.person) : null,
                    ),
                    title: Text(userData['nickname'] ?? '不明なユーザー'),
                    subtitle: Text(userData['bio'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => UserProfileScreen(userId: userIds[index]),
                      ));
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