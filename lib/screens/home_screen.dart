import 'package:flutter/material.dart';
import 'timeline_screen.dart';
import 'my_page_screen.dart';
import 'post_screen.dart';
import 'chat_list_screen.dart';
import 'matching_screen.dart'; // ★★★ 新しくインポート ★★★

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // ★★★ マッチング画面を追加 ★★★
  final List<Widget> _pages = [
    const TimelineScreen(),
    const MatchingScreen(), // 2番目にマッチング画面を追加
    const ChatListScreen(),
    const MyPageScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showPostScreen(BuildContext context) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const PostScreen(),
    );

    if (result == true) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿しました！')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _pages[_selectedIndex],
          if (_selectedIndex == 0)
            Positioned(
              bottom: 20,
              right: 16,
              child: FloatingActionButton(
                onPressed: () => _showPostScreen(context),
                child: const Icon(Icons.add),
              ),
            ),
        ],
      ),
      // ★★★ ナビゲーションバーの項目を更新 ★★★
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 項目が4つ以上なのでfixedにする
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.swipe_outlined), activeIcon: Icon(Icons.swipe), label: '探す'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'メッセージ'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'マイページ'),
        ],
      ),
    );
  }
}