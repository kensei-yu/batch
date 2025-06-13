import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart';
import 'welcome_screen.dart';
import 'follow_list_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({Key? key}) : super(key: key);

  @override
  _MyPageScreenState createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final user = FirebaseAuth.instance.currentUser;

  Future<Map<String, dynamic>?> _loadUserProfile() async {
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    return doc.exists ? doc.data() : {'email': user!.email};
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしてもよろしいですか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ログアウト', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }
  
  Future<void> _editProfile() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
    if (result == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text('ログインしていません。')));
    }
    
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadUserProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Scaffold(body: Center(child: Text('ユーザー情報の取得に失敗しました。')));
        }
        
        final userProfile = snapshot.data!;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 220.0,
                    floating: false,
                    pinned: true,
                    stretch: true,
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: true,
                      title: Text(
                        userProfile['nickname'] ?? 'ゲストユーザー',
                        style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            userProfile['headerImageUrl'] ?? 'https://media.istockphoto.com/id/1391884768/ja/%E3%83%99%E3%82%AF%E3%82%BF%E3%83%BC/%E3%82%AA%E3%83%AB%E3%82%BF%E3%83%8A%E3%83%86%E3%82%A3%E3%83%96%E3%83%90%E3%83%B3%E3%83%89%E3%83%9F%E3%83%A5%E3%83%BC%E3%82%B8%E3%82%B7%E3%83%A3%E3%83%B3%E3%82%B3%E3%83%B3%E3%82%B5%E3%83%BC%E3%83%88%E3%81%A8%E7%BE%A4%E8%A1%86%E3%81%AE%E3%82%B7%E3%83%AB%E3%82%A8%E3%83%83%E3%83%88.jpg?s=612x612&w=0&k=20&c=ChiWOuYHqUg7kq3370VtJ5KezNrt7qmBU33ThXYoqtw=',
                            fit: BoxFit.cover,
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(0.0, 0.5),
                                end: Alignment.center,
                                colors: <Color>[
                                  Color(0x60000000),
                                  Color(0x00000000),
                                ],
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
                                  backgroundImage: userProfile['imageUrl'] != null ? NetworkImage(userProfile['imageUrl']) : null,
                                  child: userProfile['imageUrl'] == null ? const Icon(Icons.person, size: 45) : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  children: [
                                     _buildFollowStats(user!.uid),
                                     const SizedBox(height: 8),
                                     SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _editProfile,
                                        child: const Text('プロフィールを編集'),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '@${userProfile['email']?.split('@')[0] ?? 'guest'}',
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
                      const TabBar(
                        indicatorColor: Colors.black,
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        tabs: [
                          Tab(text: '投稿'),
                          Tab(text: 'いいね'),
                        ],
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
                    if (!userSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    final authorData = userSnapshot.data!.data() as Map<String, dynamic>;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: authorData['imageUrl'] != null
                              ? NetworkImage(authorData['imageUrl'])
                              : null,
                          child: authorData['imageUrl'] == null
                              ? const Icon(Icons.person)
                              : null,
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
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}