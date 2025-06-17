// lib/screens/chat_screen.dart
// このコードでファイル全体を置き換えてください。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> peerUser;

  const ChatScreen({Key? key, required this.peerUser}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  String? chatRoomId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _createChatRoomId();
    _resetUnreadCount(); // 画面を開いたら未読数をリセット
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
    chatRoomId = currentUserId.compareTo(peerUserId) > 0 ? '$currentUserId\_$peerUserId' : '$peerUserId\_$currentUserId';
  }

  // ▼▼▼【ここから修正】▼▼▼
  // このチャットルームの自分の未読数を0にする
  void _resetUnreadCount() {
    if (chatRoomId == null || _currentUser == null) return;
    // ドキュメントが存在する場合のみ更新する
    FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).get().then((doc) {
      if (doc.exists) {
        doc.reference.update({'unreadCount_${_currentUser!.uid}': 0});
      }
    });
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || chatRoomId == null || _currentUser == null) return;

    setState(() { _isSending = true; });

    final myId = _currentUser!.uid;
    final recipientId = widget.peerUser['uid'];
    final chatRoomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId!);
    final newMessageRef = chatRoomRef.collection('messages').doc();

    // チャットルームの情報を更新
    // 相手の未読数を1増やす
    final chatRoomData = {
      'userIds': [myId, recipientId],
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'lastMessage': messageText,
      'unreadCount_$recipientId': FieldValue.increment(1), // 相手の未読数をインクリメント
    };

    // 新しいメッセージのデータ
    final messageData = {
      'senderId': myId,
      'message': messageText,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      // バッチ処理で複数の書き込みを一度に実行
      final batch = FirebaseFirestore.instance.batch();
      batch.set(chatRoomRef, chatRoomData, SetOptions(merge: true)); // merge:trueで既存フィールドを上書きしない
      batch.set(newMessageRef, messageData);
      await batch.commit();

      _messageController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('メッセージの送信に失敗しました: $e')));
    } finally {
      if (mounted) setState(() { _isSending = false; });
    }
  }
  // ▲▲▲【ここまで修正】▲▲▲

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                alignment: WrapAlignment.spaceAround,
                children: [
                  _buildMenuOption(icon: Icons.photo_outlined, label: '画像', onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('画像送信は準備中です'))); }),
                  _buildMenuOption(icon: Icons.videocam_outlined, label: '動画', onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('動画送信は準備中です'))); }),
                  _buildMenuOption(icon: Icons.mic_none, label: '音声', onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ボイスメッセージは準備中です'))); }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? peerImageUrl = widget.peerUser['imageUrl'];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.peerUser['nickname'] ?? 'チャット',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: chatRoomId == null
                ? const Center(child: Text("チャットルームの情報の読み込みに失敗しました。"))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId!).collection('messages').orderBy('timestamp', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('メッセージを送信して\nチャットを開始しましょう', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])));
                      
                      final messages = snapshot.data!.docs;
                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                           final message = messages[index].data() as Map<String, dynamic>;
                           final bool isMe = message['senderId'] == _currentUser?.uid;
                           return _MessageBubble(
                            message: message['message'] ?? '', 
                            isMe: isMe,
                            peerImageUrl: peerImageUrl,
                          );
                        },
                      );
                    },
                  ),
          ),
          _buildMessageInputField(),
        ],
      ),
    );
  }

  Widget _buildMessageInputField() {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: Colors.grey.shade200))
        ),
        child: SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: Colors.grey.shade600,
                onPressed: _showAttachmentMenu,
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLines: 5,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'メッセージを入力...',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  ),
                  onChanged: (text) => setState(() {}),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send_rounded, color: Theme.of(context).colorScheme.primary),
                onPressed: _isSending || _messageController.text.trim().isEmpty ? null : _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String? peerImageUrl;

  const _MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.peerImageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: (peerImageUrl != null && peerImageUrl!.isNotEmpty) 
                  ? NetworkImage(peerImageUrl!) 
                  : null,
              child: (peerImageUrl == null || peerImageUrl!.isEmpty) 
                  ? const Icon(Icons.person, size: 16) 
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: isMe ? Theme.of(context).colorScheme.primary : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                ),
              ),
              child: Text(
                message,
                style: TextStyle(color: isMe ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}