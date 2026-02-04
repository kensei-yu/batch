// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'timeline_screen.dart';
import 'my_page_screen.dart';
import 'post_screen.dart';
import 'chat_list_screen.dart';
import 'matching_screen.dart';
import 'create_recruitment_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _currentUser = FirebaseAuth.instance.currentUser;

  static const List<Widget> _pages = [
    TimelineScreen(),
    MatchingScreen(),
    ChatListScreen(),
    MyPageScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showPostScreen(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const PostScreen(),
        fullscreenDialog: true,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿しました！')),
      );
    }
  }

  void _showCreateRecruitmentScreen(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateRecruitmentScreen(),
        fullscreenDialog: true,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('募集を作成しました！')),
      );
    }
  }
  
  // チャットアイコンに未読数バッジを付けるためのウィジェット
  Widget _buildChatIconWithBadge(bool isActive) {
    // アイコンの色をアクティブかどうかで決定
    final iconColor = isActive 
        ? Theme.of(context).bottomNavigationBarTheme.selectedItemColor 
        : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor;

    // ログインしていない場合はバッジを表示しない
    if (_currentUser == null) {
      return Icon(isActive ? Icons.chat_bubble : Icons.chat_bubble_outline, color: iconColor);
    }
    
    // 全てのチャットルームの自分の未読数を合計して表示
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
              .collection('chat_rooms')
              .where('userIds', arrayContains: _currentUser!.uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          // データがない場合は通常のアイコンを表示
          return Icon(isActive ? Icons.chat_bubble : Icons.chat_bubble_outline, color: iconColor);
        }

        int totalUnreadCount = 0;
        // 全てのチャットルームをループして未読数を合計
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          // 自分の未読数を取得して加算
          final unreadData = data['unreadCount_${_currentUser!.uid}'];
          if (unreadData is num) {
            totalUnreadCount += unreadData.toInt();
          }
        }

        // Badgeウィジェットでアイコンと未読数を表示
        return Badge(
          label: Text('$totalUnreadCount'),
          isLabelVisible: totalUnreadCount > 0, // 未読数が0より大きい場合のみバッジを表示
          child: Icon(isActive ? Icons.chat_bubble : Icons.chat_bubble_outline, color: iconColor),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showPostScreen(context),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'ホーム'),
          const BottomNavigationBarItem(icon: Icon(Icons.swipe_outlined), activeIcon: Icon(Icons.swipe), label: '探す'),
          // チャットタブのアイコンをバッジ付きのものに差し替え
          BottomNavigationBarItem(
            icon: _buildChatIconWithBadge(false), // 非アクティブ時のアイコン
            activeIcon: _buildChatIconWithBadge(true), // アクティブ時のアイコン
            label: 'メッセージ',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'マイページ'),
        ],
      ),
    );
  }
}