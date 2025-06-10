import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package.cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart';
import 'welcome_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({Key? key}) : super(key: key);

  @override
  _MyPageScreenState createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // タブを2つ作成
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() { _isLoading = true; });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) {
          if (doc.exists) {
            setState(() {
              _userProfile = doc.data();
              _isLoading = false;
            });
          } else {
            setState(() {
              _userProfile = {'email': user.email};
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() { _isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('プロフィール情報の取得に失敗しました: $e')));
        }
      }
    } else {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }
  
  // ログアウト処理
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
  
  // プロフィール編集画面へ遷移
  Future<void> _editProfile() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
    if (result == true && mounted) {
      _loadUserProfile();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBarを削除し、CustomScrollViewで柔軟なUIを構築
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userProfile == null
              ? const Center(child: Text('ユーザー情報が取得できませんでした。'))
              : DefaultTabController(
                  length: 2,
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      return [
                        SliverAppBar(
                          expandedHeight: 200.0, // ヘッダーの高さを調整
                          floating: false,
                          pinned: true,
                          automaticallyImplyLeading: false, // 戻るボタンを非表示
                           actions: [
                            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
                          ],
                          flexibleSpace: FlexibleSpaceBar(
                            background: Image.network(
                              // TODO: ヘッダー画像用のURLをFirestoreに保存して利用する
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
                                        backgroundImage: _userProfile?['imageUrl'] != null ? NetworkImage(_userProfile!['imageUrl']) : null,
                                        child: _userProfile?['imageUrl'] == null ? const Icon(Icons.person, size: 40) : null,
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
                                  _userProfile?['nickname'] ?? 'ゲストユーザー',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '@${_userProfile?['email']?.split('@')[0] ?? 'guest'}', // メールアドレスの@前を表示
                                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _userProfile?['bio'] ?? '自己紹介がありません。',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 16),
                                const Row(
                                  children: [
                                    Text('123', style: TextStyle(fontWeight: FontWeight.bold)),
                                    SizedBox(width: 4),
                                    Text('フォロー中', style: TextStyle(color: Colors.grey)),
                                    SizedBox(width: 16),
                                    Text('456', style: TextStyle(fontWeight: FontWeight.bold)),
                                    SizedBox(width: 4),
                                    Text('フォロワー', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                         SliverPersistentHeader(
                          delegate: _SliverAppBarDelegate(
                            TabBar(
                              controller: _tabController,
                              tabs: const [
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
                      controller: _tabController,
                      children: [
                        // 「投稿」タブの中身
                        const Center(child: Text('自分の投稿一覧がここに表示されます')),
                        // TODO: 自分の投稿一覧をFirestoreから取得して表示するウィジェットに置き換える

                        // 「いいね」タブの中身
                        const Center(child: Text('いいねした投稿一覧がここに表示されます')),
                      ],
                    ),
                  ),
                ),
    );
  }
}

// TabBarをSliverAppBarの下に固定するためのヘルパークラス
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor, // 背景色を合わせる
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}