// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> peerUser;

  const ChatScreen({Key? key, required this.peerUser}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  String? chatRoomId;
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _createChatRoomId();
    _resetUnreadCount();
    _messageController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _createChatRoomId() {
    if (_currentUser == null || widget.peerUser['uid'] == null) return;
    final currentUserId = _currentUser!.uid;
    final peerUserId = widget.peerUser['uid']!;
    if (currentUserId.compareTo(peerUserId) > 0) {
      chatRoomId = '$currentUserId\_$peerUserId';
    } else {
      chatRoomId = '$peerUserId\_$currentUserId';
    }
  }

  void _resetUnreadCount() {
    if (chatRoomId == null || _currentUser == null) return;
    FirebaseFirestore.instance
      .collection('chat_rooms')
      .doc(chatRoomId)
      .set({
        'unreadCount_${_currentUser!.uid}': 0,
      }, SetOptions(merge: true));
  }

  // ▼▼▼【これが最終確定版のメッセージ送信ロジックです】▼▼▼
  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || chatRoomId == null || _currentUser == null) return;

    setState(() { _isSending = true; });

    final myId = _currentUser!.uid;
    final recipientId = widget.peerUser['uid'];
    final chatRoomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot chatDoc = await transaction.get(chatRoomRef);

        int newUnreadCount = 1;

        if (chatDoc.exists) {
          // ドキュメントが既に存在する場合
          final data = chatDoc.data() as Map<String, dynamic>;
          final key = 'unreadCount_$recipientId';
          if (data.containsKey(key)) {
            newUnreadCount = (data[key] as num).toInt() + 1;
          }

          // transaction.updateを使ってドキュメントを「更新」
          transaction.update(chatRoomRef, {
            'lastUpdatedAt': FieldValue.serverTimestamp(),
            'lastMessage': messageText,
            'unreadCount_$recipientId': newUnreadCount,
            'unreadCount_$myId': 0,
          });

        } else {
          // ドキュメントが存在しない場合（最初のメッセージ）
          // transaction.setを使ってドキュメントを「新規作成」
          transaction.set(chatRoomRef, {
            'userIds': [myId, recipientId],
            'lastUpdatedAt': FieldValue.serverTimestamp(),
            'lastMessage': messageText,
            'unreadCount_$recipientId': newUnreadCount,
            'unreadCount_$myId': 0,
          });
        }

        // 新しいメッセージをサブコレクションに追加
        final messagesRef = chatRoomRef.collection('messages').doc();
        transaction.set(messagesRef, {
          'senderId': myId,
          'message': messageText,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      _messageController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('メッセージの送信に失敗しました: $e')));
      }
    } finally {
      if(mounted) { setState(() { _isSending = false; }); }
    }
  }

  // buildメソッドは変更なしのため、省略
  @override
  Widget build(BuildContext context) {
    final String? peerImageUrl = widget.peerUser['imageUrl'];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        title: Row(children: [
            CircleAvatar(radius: 18, backgroundImage: (peerImageUrl != null && peerImageUrl.isNotEmpty) ? NetworkImage(peerImageUrl) : null, child: (peerImageUrl == null || peerImageUrl.isEmpty) ? const Icon(Icons.person, size: 18) : null),
            const SizedBox(width:12),
            Text(widget.peerUser['nickname'] ?? 'チャット'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: chatRoomId == null
                  ? const Center(child: Text("チャット相手の情報の読み込みに失敗しました。"))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return Center(child: Text('エラーが発生しました。'));
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('メッセージを送信してチャットを開始しましょう'));
                        final messages = snapshot.data!.docs;
                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                             final message = messages[index];
                             final data = message.data() as Map<String, dynamic>;
                             final bool isCurrentUser = data['senderId'] == _currentUser?.uid;
                             return Align(
                                alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                                  margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                  padding: const EdgeInsets.all(12.0),
                                  decoration: BoxDecoration(color: isCurrentUser ? Theme.of(context).primaryColorLight.withOpacity(0.8) : Colors.grey[200], borderRadius: BorderRadius.circular(12.0)),
                                  child: Text(data['message'] ?? '', style: const TextStyle(color: Colors.black87)),
                                ),
                              );
                          },
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, -3))]),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 5,
                      minLines: 1,
                      decoration: InputDecoration(hintText: 'メッセージを入力...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20.0), borderSide: BorderSide.none), fillColor: Colors.grey.withOpacity(0.1), filled: true, contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isSending
                    ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(icon: const Icon(Icons.send), color: Theme.of(context).primaryColor, onPressed: _messageController.text.isNotEmpty ? _sendMessage : null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}