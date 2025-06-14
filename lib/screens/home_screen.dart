// lib/screens/home_screen.dart
// このコードをファイル全体に貼り付けてください。

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'timeline_screen.dart';
import 'my_page_screen.dart';
import 'post_screen.dart';
import 'chat_list_screen.dart';
import 'matching_screen.dart';

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

  // ▼▼▼【ここを修正】投稿画面をフルスクリーンで表示する ▼▼▼
  void _showPostScreen(BuildContext context) async {
    // Navigator.push を使って全画面表示し、結果を受け取る
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const PostScreen(),
        fullscreenDialog: true, // 下からスライドインするアニメーション
      ),
    );

    // 投稿が成功した場合（result == true）にスナックバーを表示
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿しました！')),
      );
    }
  }
  
  Widget _buildChatIconWithBadge(bool isActive) {
    final iconColor = isActive ? Theme.of(context).bottomNavigationBarTheme.selectedItemColor : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor;

    if (_currentUser == null) {
      return Icon(isActive ? Icons.chat_bubble : Icons.chat_bubble_outline, color: iconColor);
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
              .collection('chat_rooms')
              .where('userIds', arrayContains: _currentUser!.uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return Icon(isActive ? Icons.chat_bubble : Icons.chat_bubble_outline, color: iconColor);
        }

        int totalUnreadCount = 0;
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final unreadData = data['unreadCount_${_currentUser!.uid}'];
          if (unreadData is num) {
            totalUnreadCount += unreadData.toInt();
          }
        }

        return Badge(
          label: Text('$totalUnreadCount'),
          isLabelVisible: totalUnreadCount > 0,
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
          BottomNavigationBarItem(
            icon: _buildChatIconWithBadge(false),
            activeIcon: _buildChatIconWithBadge(true),
            label: 'メッセージ',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'マイページ'),
        ],
      ),
    );
  }
}