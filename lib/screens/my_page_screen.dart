import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart';
import 'welcome_screen.dart';

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
    if (doc.exists) {
      return doc.data();
    }
    return {'email': user!.email}; // フォールバック
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
                    expandedHeight: 200.0,
                    floating: false,
                    pinned: true,
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: userProfile['headerImageUrl'] != null
                        ? Image.network(
                            userProfile['headerImageUrl'],
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            'https://images.unsplash.com/photo-1504805572947-34fad45aed93?q=80&w=2070&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
                            fit: BoxFit.cover,
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 38,
                                  backgroundImage: userProfile['imageUrl'] != null ? NetworkImage(userProfile['imageUrl']) : null,
                                  child: userProfile['imageUrl'] == null ? const Icon(Icons.person, size: 40) : null,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _editProfile,
                                child: const Text('プロフィールを編集'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            userProfile['nickname'] ?? 'ゲストユーザー',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${userProfile['email']?.split('@')[0] ?? 'guest'}',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            userProfile['bio'] ?? '自己紹介がありません。',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          _buildFollowStats(user!.uid),
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
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(userId).collection('following').snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
            return Text('$count', style: const TextStyle(fontWeight: FontWeight.bold));
          },
        ),
        const SizedBox(width: 4),
        const Text('フォロー中', style: TextStyle(color: Colors.grey)),
        const SizedBox(width: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(userId).collection('followers').snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
            return Text('$count', style: const TextStyle(fontWeight: FontWeight.bold));
          },
        ),
        const SizedBox(width: 4),
        const Text('フォロワー', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildUserPostsView(String userId) {
    // 【デバッグ用プリント】この関数がどのユーザーIDで呼ばれたかを確認
    print("--- 投稿一覧表示を開始: ユーザーID = $userId ---");

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // 【デバッグ用プリント】エラーが発生した場合に内容を表示
        if (snapshot.hasError) {
          print("--- 投稿一覧でエラー発生: ${snapshot.error} ---");
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 【デバッグ用プリント】取得した投稿の件数を表示
        final postCount = snapshot.data?.docs.length ?? 0;
        print("--- 投稿一覧のデータ受信: $postCount 件 ---");

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
    // 【デバッグ用プリント】この関数がどのユーザーIDで呼ばれたかを確認
    print("--- いいね一覧表示を開始: ユーザーID = $userId ---");

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('liked_posts')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // 【デバッグ用プリント】エラーが発生した場合に内容を表示
        if (snapshot.hasError) {
          print("--- いいね一覧でエラー発生: ${snapshot.error} ---");
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 【デバッグ用プリント】取得した「いいね」の件数を表示
        final likedCount = snapshot.data?.docs.length ?? 0;
        print("--- いいね一覧のデータ受信: $likedCount 件 ---");

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('いいねした投稿がありません。'));
        }

        final likedPostIds = snapshot.data!.docs.map((doc) => doc.id).toList();
        
        // 【デバッグ用プリント】いいねした投稿のIDリストを表示
        print("--- いいねした投稿のIDリスト: $likedPostIds ---");

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