// lib/screens/chat_screen.dart

// 変更点: 'dart:io' はWebで使えないため削除します。
// import 'dart:io'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;


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
  
  // 変更点: 'File'の代わりにクロスプラットフォームで使える 'XFile' を使用します。
  XFile? _imageFile;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _createChatRoomId();
    _resetUnreadCount();
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
    final peerUserId = widget.peerUser['uid'] as String; // 安全のためStringにキャスト
    chatRoomId = currentUserId.compareTo(peerUserId) > 0 ? '$currentUserId\_$peerUserId' : '$peerUserId\_$currentUserId';
  }

  void _resetUnreadCount() {
    if (chatRoomId == null || _currentUser == null) return;
    FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).get().then((doc) {
      if (doc.exists) {
        doc.reference.update({'unreadCount_${_currentUser!.uid}': 0});
      }
    });
  }
  
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      // 変更点: Fileオブジェクトに変換せず、XFileのままセットします。
      setState(() => _imageFile = pickedFile);
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty && _imageFile == null) return;
    if (chatRoomId == null || _currentUser == null) return;

    setState(() { _isSending = true; });

    try {
      String? imageUrl;
      if (_imageFile != null) {
        // 変更点: Webでもファイル名が取得できる `_imageFile.name` を使います。
        final fileName = DateTime.now().millisecondsSinceEpoch.toString() + path.extension(_imageFile!.name);
        final ref = FirebaseStorage.instance.ref('chat_images/$chatRoomId/$fileName');
        
        // 変更点: putFileの代わりにputDataを使い、バイトデータからアップロードします。
        // これによりWebでもモバイルでも動作します。
        await ref.putData(await _imageFile!.readAsBytes());
        imageUrl = await ref.getDownloadURL();
      }

      final myId = _currentUser!.uid;
      final recipientId = widget.peerUser['uid'];
      final chatRoomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId!);
      final newMessageRef = chatRoomRef.collection('messages').doc();

      String lastMessage = messageText.isNotEmpty ? messageText : '画像が送信されました';

      final chatRoomData = {
        'userIds': [myId, recipientId],
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'lastMessage': lastMessage,
        'unreadCount_$recipientId': FieldValue.increment(1),
      };

      final messageData = {
        'senderId': myId,
        'message': messageText,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      };

      final batch = FirebaseFirestore.instance.batch();
      batch.set(chatRoomRef, chatRoomData, SetOptions(merge: true));
      batch.set(newMessageRef, messageData);
      await batch.commit();

      _messageController.clear();
      setState(() => _imageFile = null);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('メッセージの送信に失敗しました: $e')));
    } finally {
      if (mounted) setState(() { _isSending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final peerImageUrl = widget.peerUser['imageUrl'] as String?;
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
                             messageData: message,
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
      decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_imageFile != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      height: 100,
                      width: 100,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                      // 変更点: Image.fileからImage.networkに変更。
                      // WebではXFile.pathはblob URLを指すため、これで表示できます。
                      child: Image.network(_imageFile!.path, fit: BoxFit.cover),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, color: Colors.white, size: 16)),
                      onPressed: () => setState(() => _imageFile = null),
                    )
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: Colors.grey.shade600,
                    onPressed: _pickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 5, minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'メッセージを入力...',
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send_rounded, color: Theme.of(context).colorScheme.primary),
                    onPressed: _isSending || (_messageController.text.trim().isEmpty && _imageFile == null) ? null : _sendMessage,
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

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> messageData;
  final bool isMe;
  final String? peerImageUrl;

  const _MessageBubble({
    Key? key,
    required this.messageData,
    required this.isMe,
    this.peerImageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final messageText = messageData['message'] ?? '';
    final messageImageUrl = messageData['imageUrl'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              // 修正点: `peerImageUrl`がnullでないことを確認してから`NetworkImage`に渡します。
              // これでNull Safetyエラーを防ぎます。
              backgroundImage: peerImageUrl != null ? NetworkImage(peerImageUrl!) : null,
              child: peerImageUrl == null ? const Icon(Icons.person, color: Colors.white, size: 16) : null,
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
              decoration: BoxDecoration(
                color: isMe ? Theme.of(context).colorScheme.primary : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (messageImageUrl != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: messageText.isNotEmpty ? 8.0 : 0.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          messageImageUrl,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  if (messageText.isNotEmpty)
                    Text(
                      messageText,
                      style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}