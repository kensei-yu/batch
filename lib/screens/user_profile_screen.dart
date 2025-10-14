// lib/screens/user_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart';
import 'follow_list_screen.dart';
import 'chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  Future<Map<String, dynamic>?> _loadUserProfile() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> _toggleFollow() async {
    if (_currentUser == null) return;
    final currentUserId = _currentUser!.uid;
    final targetUserId = widget.userId;

    final followingRef = FirebaseFirestore.instance.collection('users').doc(currentUserId).collection('following').doc(targetUserId);
    final followerRef = FirebaseFirestore.instance.collection('users').doc(targetUserId).collection('followers').doc(currentUserId);

    final doc = await followingRef.get();
    
    if (doc.exists) {
      await followingRef.delete();
      await followerRef.delete();
    } else {
      await followingRef.set({'timestamp': FieldValue.serverTimestamp()});
      await followerRef.set({'timestamp': FieldValue.serverTimestamp()});
    }
    
    if (mounted) {
      setState(() {});
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isCurrentUser = _currentUser?.uid == widget.userId;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadUserProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const Scaffold(body: Center(child: Text('ユーザー情報の取得に失敗しました。')));
        }
        
        final userProfile = snapshot.data!;
        final headerImageUrl = userProfile['headerImageUrl'] as String?;
        final profileImageUrl = userProfile['imageUrl'] as String?;

        return DefaultTabController(
          length: isCurrentUser ? 2 : 1,
          child: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 220.0,
                    floating: false,
                    pinned: true,
                    stretch: true,
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: true,
                      title: Text(
                        userProfile['nickname'] ?? '新規ユーザー',
                        style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            headerImageUrl ?? 'https://thumb.ac-illust.com/bf/bf1ef42656626562ce9bfe28807c4e92_t.jpeg',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey),
                          ),
                           const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(0.0, 0.5),
                                end: Alignment.center,
                                colors: <Color>[Color(0x60000000), Color(0x00000000)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 45,
                                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                child: CircleAvatar(
                                  radius: 42,
                                  backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                                  backgroundColor: Colors.grey.shade300,
                                  child: profileImageUrl == null ? const Icon(Icons.person, size: 45, color: Colors.white) : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildFollowStats(widget.userId),
                                    const SizedBox(height: 8),
                                     if (!isCurrentUser)
                                      SizedBox(
                                        width: double.infinity,
                                        child: StreamBuilder<DocumentSnapshot>(
                                          stream: _currentUser != null ? FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).collection('following').doc(widget.userId).snapshots() : null,
                                          builder: (context, snapshot) {
                                            if (!snapshot.hasData) return const SizedBox();
                                            final bool isFollowing = snapshot.data!.exists;
                                            return ElevatedButton(
                                              onPressed: _toggleFollow,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isFollowing ? Colors.grey : Theme.of(context).primaryColor,
                                              ),
                                              child: Text(isFollowing ? 'フォロー中' : 'フォロー', style: const TextStyle(color: Colors.white)),
                                            );
                                          },
                                        ),
                                      )
                                     else
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                             final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
                                             if (result == true && mounted) {
                                               setState(() {});
                                             }
                                          },
                                          child: const Text('プロフィールを編集'),
                                        ),
                                      ),
                                       if (!isCurrentUser)
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton(
                                            onPressed: () {
                                              Navigator.push(context, MaterialPageRoute(
                                                  builder: (context) => ChatScreen(peerUser: {
                                                      'uid': widget.userId,
                                                      'nickname': userProfile['nickname'] ?? '不明なユーザー',
                                                      'imageUrl': userProfile['imageUrl'],
                                                  }),
                                              ));
                                            },
                                            child: const Text('チャットする'),
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '@${userProfile['username'] ?? 'guest'}',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            userProfile['bio'] ?? '自己紹介がありません。',
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                   SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        indicatorColor: Colors.black,
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        tabs: [
                          const Tab(text: '投稿'),
                          if (isCurrentUser) const Tab(text: 'いいね'),
                        ],
                      ),
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  _buildUserPostsView(widget.userId),
                  if (isCurrentUser) _buildLikedPostsView(widget.userId),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFollowStats(String userId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => FollowListScreen(userId: userId, listType: 'following'),
            ));
          },
          child: Column(
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(userId).collection('following').snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
                },
              ),
              const Text('フォロー中', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => FollowListScreen(userId: userId, listType: 'followers'),
            ));
          },
          child: Column(
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(userId).collection('followers').snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
                },
              ),
              const Text('フォロワー', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserPostsView(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
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
          return const Center(child: Text('まだ投稿がありません。'));
        }
        final posts = snapshot.data!.docs;
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final data = post.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(data['content'] ?? ''),
                subtitle: Text((data['timestamp'] as Timestamp?)?.toDate().toLocal().toString() ?? ''),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLikedPostsView(String userId) {
     return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('liked_posts')
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
          return const Center(child: Text('いいねした投稿がありません。'));
        }
        final likedPostIds = snapshot.data!.docs.map((doc) => doc.id).toList();
        if (likedPostIds.isEmpty) {
           return const Center(child: Text('いいねした投稿がありません。'));
        }

        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(likedPostIds.map((id) => FirebaseFirestore.instance.collection('posts').doc(id).get())),
          builder: (context, postSnapshots) {
             if (postSnapshots.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!postSnapshots.hasData) {
              return const Center(child: Text('投稿の取得に失敗しました。'));
            }

            final posts = postSnapshots.data!.where((doc) => doc.exists).toList();
            return ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final postDoc = posts[index];
                final postData = postDoc.data() as Map<String, dynamic>;
                final String postAuthorId = postData['userId'];

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(postAuthorId).get(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                       return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text(postData['content'] ?? ''),
                          subtitle: const Text('読み込み中...'),
                        ),
                      );
                    }
                    if (!userSnapshot.hasData || !userSnapshot.data!.exists) return const SizedBox.shrink();
                    
                    final authorData = userSnapshot.data!.data() as Map<String, dynamic>;
                    final authorImageUrl = authorData['imageUrl'] as String?;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: authorImageUrl != null ? NetworkImage(authorImageUrl) : null,
                          backgroundColor: Colors.grey.shade300,
                          child: authorImageUrl == null
                              ? const Icon(Icons.person, color: Colors.white) : null,
                        ),
                        title: Text(authorData['nickname'] ?? 'ゲスト', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(postData['content'] ?? ''),
                      ),
                    );
                  },
                );
              },
            );
          }
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  const _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}