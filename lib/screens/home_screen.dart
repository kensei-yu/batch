import 'package:flutter/material.dart';
import 'timeline_screen.dart';
import 'chat_screen.dart';
import 'my_page_screen.dart';
import 'post_screen.dart'; // PostScreen をインポート

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const TimelineScreen(),
    const ChatScreen(),
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

    if (result == true) { // 投稿が成功した場合
      if(!mounted) return;
      // タイムラインに戻り、SnackBarを表示
      // setState(() {
      //   _selectedIndex = 0; // 投稿後、ホーム（タイムライン）に戻す場合
      // });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿しました！')),
      );
       // タイムラインをリフレッシュするために、一度他のタブに移動して戻るか、
       // もしくはTimelineScreen側でStatefulWidgetにして投稿イベントをリッスンするなどの工夫が必要
       // ここではシンプルにSnackBarのみ表示
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _pages[_selectedIndex],
          if (_selectedIndex == 0) // ホームタブ（TimelineScreen）の時のみ表示
            Positioned(
              bottom: 20, // BottomNavigationBarとの兼ね合いで調整
              right: 16,
              child: FloatingActionButton(
                onPressed: () => _showPostScreen(context),
                child: const Icon(Icons.add),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'チャット'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'マイページ'),
        ],
      ),
    );
  }
}