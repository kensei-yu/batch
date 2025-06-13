// lib/screens/home_screen.dart

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

  // ▼▼▼【ここが修正点です】▼▼▼
  final List<Widget> _pages = [
    const TimelineScreen(),
    const MatchingScreen(),
    const ChatListScreen(), // const を削除しました
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

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿しました！')),
      );
    }
  }
  
  Widget _buildChatIconWithBadge(bool isActive) {
    return StreamBuilder<QuerySnapshot>(
      stream: _currentUser != null
          ? FirebaseFirestore.instance
              .collection('chat_rooms')
              .where('userIds', arrayContains: _currentUser!.uid)
              .snapshots()
          : null,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return Icon(isActive ? Icons.chat_bubble : Icons.chat_bubble_outline);
        }

        int totalUnreadCount = 0;
        for (var doc in snapshot.data!.docs) {
          dynamic unreadData = (doc.data() as Map<String, dynamic>)['unreadCount_${_currentUser!.uid}'];
          if (unreadData is num) {
            totalUnreadCount += unreadData.toInt();
          }
        }

        return Badge(
          label: Text('$totalUnreadCount'),
          isLabelVisible: totalUnreadCount > 0,
          child: Icon(isActive ? Icons.chat_bubble : Icons.chat_bubble_outline),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // _selectedIndexに応じて表示するページを切り替え
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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
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