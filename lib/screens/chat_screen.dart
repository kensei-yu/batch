// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void initState() {
    super.initState();
    _createChatRoomId();
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
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || widget.peerUser['uid'] == null) {
      return;
    }
    
    final currentUserId = currentUser.uid;
    final peerUserId = widget.peerUser['uid']!;

    if (currentUserId.compareTo(peerUserId) > 0) {
      chatRoomId = '$currentUserId\_$peerUserId';
    } else {
      chatRoomId = '$peerUserId\_$currentUserId';
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || chatRoomId == null) return;

    setState(() { _isSending = true; });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _isSending = false; });
      return;
    }

    try {
      final chatRoomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId);
      final messagesRef = chatRoomRef.collection('messages');

      // --- ▼▼▼ ここから修正 ▼▼▼ ---

      // 1. WriteBatchを初期化
      final batch = FirebaseFirestore.instance.batch();

      // 2. チャットルームの作成/更新をバッチに追加
      batch.set(chatRoomRef, {
        'userIds': [user.uid, widget.peerUser['uid']],
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'lastMessage': messageText,
      }, SetOptions(merge: true));

      // 3. 新しいメッセージの作成をバッチに追加
      // messagesRef.add() の代わりに、ドキュメント参照を先に作り batch.set() を使う
      final newMessageRef = messagesRef.doc(); 
      batch.set(newMessageRef, {
        'senderId': user.uid,
        'message': messageText,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 4. バッチ処理を一括で実行
      await batch.commit();

      // --- ▲▲▲ ここまで修正 ▲▲▲ ---
      
      _messageController.clear();
      
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if(mounted) {
        print('Message send error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('メッセージの送信に失敗しました: $e')),
        );
      }
    } finally {
      if(mounted) { setState(() { _isSending = false; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? peerImageUrl = widget.peerUser['imageUrl'];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: (peerImageUrl != null && peerImageUrl.isNotEmpty)
                  ? NetworkImage(peerImageUrl)
                  : null,
              child: (peerImageUrl == null || peerImageUrl.isEmpty)
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
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
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('chat_rooms')
                          .doc(chatRoomId)
                          .collection('messages')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          print('Message stream error: ${snapshot.error}');
                          return Center(child: Text('エラー: ${snapshot.error}'));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('メッセージを送信してみましょう'));
                        
                        final messages = snapshot.data!.docs;
                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                             final message = messages[index];
                             final data = message.data() as Map<String, dynamic>;
                             
                             // ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
                             // ★【エラー修正箇所 3/3】
                             // ★ メッセージ送信時に 'senderId' に変更したため、ここも合わせる
                             // ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
                             final bool isCurrentUser = data['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                             
                             return Align(
                                alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                                  margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                  padding: const EdgeInsets.all(12.0),
                                  decoration: BoxDecoration(
                                    color: isCurrentUser ? Theme.of(context).primaryColorLight : Colors.grey[300],
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: Text(data['message'] ?? '', style: const TextStyle(color: Colors.black87)),
                                ),
                              );
                          },
                        );
                      },
                    ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 5,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'メッセージを入力...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                      ),
                      onSubmitted: _isSending ? null : (_) => _sendMessage(),
                    ),
                  ),
                  _isSending
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _messageController.text.isNotEmpty
                            ? _sendMessage
                            : null,
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}