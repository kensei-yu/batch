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
    // メッセージ入力欄の変更を監視してUIを更新
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
      print("Error: Current user or peer user UID is null.");
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
    if (_messageController.text.trim().isEmpty || chatRoomId == null) return;

    setState(() { _isSending = true; });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _isSending = false; });
      return;
    }

    try {
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
      
      // 送信後に一番下にスクロール
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if(mounted) {
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
    // 相手のプロフィール画像のURLを取得
    final String? peerImageUrl = widget.peerUser['imageUrl'];

    return Scaffold(
      appBar: AppBar(
           leading: IconButton(
        icon: const Icon(Icons.arrow_back), // 表示したい矢印アイコン
        onPressed: () {
          Navigator.of(context).pop(); // 前の画面に戻る動作
        },
      ),
        // titleにRowウィジェットを使い、アイコンと名前を横並びにする
        title: Row(
          children: [
            // 相手のプロフィールアイコンを表示
            CircleAvatar(
              radius: 15, // アイコンのサイズを調整
              backgroundImage: (peerImageUrl != null && peerImageUrl.isNotEmpty)
                  ? NetworkImage(peerImageUrl)
                  : null,
              // 画像がない場合は人型のアイコンを表示
              child: (peerImageUrl == null || peerImageUrl.isEmpty)
                  ? const Icon(Icons.person, size: 15)
                  : null,
            ),
            const SizedBox(width:15), // アイコンと名前の間のスペース
            // 相手の名前を表示
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
                        if (snapshot.hasError) return Center(child: Text('エラー: ${snapshot.error}'));
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
            
            // メッセージ入力欄
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 「+」ボタン
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      // TODO: 「+」ボタンが押された時の動作をここに実装（画像送信など）
                      print("「+」ボタンが押されました");
                    },
                  ),
                  // メッセージ入力欄
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
                  // 送信中 or 送信/ボイスボタン
                  _isSending
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: _messageController.text.isNotEmpty
                            ? const Icon(Icons.send)
                            : const Icon(Icons.mic_none),
                        onPressed: _messageController.text.isNotEmpty
                            ? _sendMessage
                            : () {
                                // TODO: ボイスメッセージの録音開始処理
                                print("ボイスボタンが押されました");
                              },
                      ),
                ],
              ),
            ),
            // 下部の空白
            const SizedBox(height: 8.0), 
          ],
        ),
      ),
    );
  }
}