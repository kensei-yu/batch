// lib/screens/chat_screen.dart (内容を全て書き換える)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  // チャット相手のユーザー情報を保持する
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
  }
  
  void _createChatRoomId() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final currentUserId = currentUser.uid;
    final peerUserId = widget.peerUser['uid'];

    // 2人のUIDを比較し、アルファベット順に連結してIDを作成
    if (currentUserId.compareTo(peerUserId) > 0) {
      chatRoomId = '$currentUserId\_$peerUserId';
    } else {
      chatRoomId = '$peerUserId\_$currentUserId';
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || chatRoomId == null) return;

    setState(() { _isSending = true; });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _isSending = false; });
      return;
    }

    try {
      // 新しいデータ構造のパスにメッセージを書き込む
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'userId': user.uid,
        'message': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
      // ... (スクロール処理は省略)
    } catch (e) {
      // ... (エラーハンドリングは省略)
    } finally {
      if(mounted) { setState(() { _isSending = false; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBarのタイトルに相手の名前を表示
      appBar: AppBar(title: Text(widget.peerUser['nickname'] ?? 'チャット')),
      body: Column(
        children: [
          Expanded(
            child: chatRoomId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    // 新しいデータ構造のパスからメッセージを読み込む
                    stream: FirebaseFirestore.instance
                        .collection('chat_rooms')
                        .doc(chatRoomId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      // ... (元のListView.builderのロジックはほぼ同じなので流用)
                      if (snapshot.hasError) return Center(child: Text('エラー: ${snapshot.error}'));
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('メッセージを送信してみましょう'));
                      
                      final messages = snapshot.data!.docs;
                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                           final message = messages[index];
                           final data = message.data() as Map<String, dynamic>;
                           final bool isCurrentUser = data['userId'] == FirebaseAuth.instance.currentUser?.uid;
                           return Align(
                              alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
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
          // メッセージ入力欄のUIは変更なし
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(hintText: 'メッセージを入力...', border: OutlineInputBorder()),
                    onSubmitted: _isSending ? null : (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}