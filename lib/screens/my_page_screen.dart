// lib/screens/my_page_screen.dart
// このコードでファイル全体を置き換えてください。

import 'package:batch/screens/edit_profile_screen.dart';
import 'package:batch/screens/follow_list_screen.dart';
import 'package:batch/screens/post_detail_screen.dart';
import 'package:batch/screens/welcome_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({Key? key}) : super(key: key);

  @override
  _MyPageScreenState createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final String defaultHeaderImageUrl = 'https://t4.ftcdn.net/jpg/07/20/08/81/360_F_720088116_Je8m4Tn7LECnkKHQEABWLvOiWlJ7Qo8V.jpg';

  // ▼▼▼【修正点】このファイルにあった_logoutメソッドは削除します ▼▼▼

  Future<void> _editProfile() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const EditProfileScreen()));
    if (result == true && mounted) {
      // StreamBuilderが自動で更新を検知するため、setStateは不要
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text('ログインしていません。')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
              body: Center(child: Text('ユーザー情報の取得に失敗しました。')));
        }

        final userProfile = snapshot.data!.data() as Map<String, dynamic>;
        final headerImageUrl = (userProfile['headerImageUrl'] as String?)?.isNotEmpty == true
            ? userProfile['headerImageUrl'] as String
            : defaultHeaderImageUrl;
        final profileImageUrl = userProfile['imageUrl'] as String?;
        final displayUsername = '@${userProfile['username'] ?? 'no_id'}';

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 250.0,
                    floating: false,
                    pinned: true,
                    stretch: true,
                    automaticallyImplyLeading: false,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    // ▼▼▼【修正点】actionsプロパティ（ログアウトボタン）を削除 ▼▼▼
                    // actions: [
                    //   IconButton(
                    //       icon: const Icon(Icons.logout_outlined),
                    //       onPressed: _logout),
                    // ],
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            headerImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(color: Colors.grey),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(0.0, 0.0),
                                end: Alignment(0.0, 0.5),
                                colors: <Color>[
                                  Color(0x60000000),
                                  Color(0x00000000)
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  child: CircleAvatar(
                                    radius: 37,
                                    backgroundImage: (profileImageUrl != null &&
                                            profileImageUrl.isNotEmpty)
                                        ? NetworkImage(profileImageUrl)
                                        : null,
                                    child: (profileImageUrl == null ||
                                            profileImageUrl.isEmpty)
                                        ? const Icon(Icons.person, size: 40)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      userProfile['nickname'] ?? 'ゲストユーザー',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        shadows: [Shadow(blurRadius: 2, color: Colors.black.withOpacity(0.7))],
                                      ),
                                    ),
                                    Text(
                                      displayUsername,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        shadows: [Shadow(blurRadius: 2, color: Colors.black.withOpacity(0.7))],
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userProfile['bio'] ?? '自己紹介がありません。',
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          _buildFollowStats(user!.uid),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _editProfile,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade400),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                              child: const Text('プロフィールを編集'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      const TabBar(
                        indicatorSize: TabBarIndicatorSize.label,
                        indicatorWeight: 3.0,
                        tabs: [Tab(text: '投稿'), Tab(text: 'いいね')],
                      ),
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  _buildUserPostsView(user!.uid),
                  _buildLikedPostsView(user!.uid),
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
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      FollowListScreen(userId: userId, listType: 'following'))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('following')
                    .snapshots(),
                builder: (context, snapshot) => Text(
                    '${snapshot.data?.docs.length ?? 0}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(width: 4),
              const Text('フォロー中', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      FollowListScreen(userId: userId, listType: 'followers'))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('followers')
                    .snapshots(),
                builder: (context, snapshot) => Text(
                    '${snapshot.data?.docs.length ?? 0}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(width: 4),
              const Text('フォロワー', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
        if (snapshot.hasError) return Center(child: Text('エラー: ${snapshot.error}'));
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
                subtitle: Text((data['timestamp'] as Timestamp?)
                        ?.toDate()
                        .toLocal()
                        .toString()
                        .substring(0, 16) ??
                    ''),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PostDetailScreen(postId: post.id))),
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
        if (snapshot.hasError) return Center(child: Text('エラー: ${snapshot.error}'));
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
            future: Future.wait(likedPostIds
                .map((id) =>
                    FirebaseFirestore.instance.collection('posts').doc(id).get())
                .toList()),
            builder: (context, postSnapshots) {
              if (postSnapshots.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (postSnapshots.hasError || !postSnapshots.hasData) {
                return const Center(child: Text('投稿の取得に失敗しました。'));
              }

              final posts =
                  postSnapshots.data!.where((doc) => doc.exists).toList();
              if (posts.isEmpty) {
                return const Center(child: Text('いいねした投稿が見つかりませんでした。'));
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final postDoc = posts[index];
                  final postData = postDoc.data() as Map<String, dynamic>;

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(postData['userId'])
                        .get(),
                    builder: (context, userSnapshot) {
                      final authorData =
                          userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                      return Card(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: authorData['imageUrl'] != null
                                ? NetworkImage(authorData['imageUrl'])
                                : null,
                            child: authorData['imageUrl'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(authorData['nickname'] ?? '...',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(postData['content'] ?? ''),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      PostDetailScreen(postId: postDoc.id))),
                        ),
                      );
                    },
                  );
                },
              );
            });
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
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}