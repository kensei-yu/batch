// lib/screens/post_detail_screen.dart
// このコードでファイル全体を貼り付けてください。

import 'package:batch/screens/user_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  String? _postAuthorId;

  @override
  void initState() {
    super.initState();
    _fetchPostAuthor();
  }
  
  Future<void> _fetchPostAuthor() async {
    try {
      final postDoc = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();
      if (postDoc.exists && mounted) {
        setState(() {
          _postAuthorId = (postDoc.data() as Map<String, dynamic>)['userId'];
        });
      }
    } catch (e) {
      print("投稿者情報の取得に失敗: $e");
    }
  }

  Future<void> _addComment() async {
    if (_postAuthorId == null || _commentController.text.trim().isEmpty || _currentUser == null) return;
    final commentText = _commentController.text.trim();
    final newCommentRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('comments').doc();
    await newCommentRef.set({ 'id': newCommentRef.id, 'userId': _currentUser!.uid, 'text': commentText, 'timestamp': FieldValue.serverTimestamp() });
    await FirebaseFirestore.instance.collection('posts').doc(widget.postId).update({'commentCount': FieldValue.increment(1)});
    _commentController.clear();
    FocusScope.of(context).unfocus();
    if (_currentUser!.uid != _postAuthorId) {
      final notificationRef = FirebaseFirestore.instance.collection('users').doc(_postAuthorId!).collection('notifications').doc();
      final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
      final currentUserNickname = currentUserDoc.data()?['nickname'] ?? '誰か';
      await notificationRef.set({ 'id': notificationRef.id, 'type': 'reply', 'senderId': _currentUser!.uid, 'message': '$currentUserNickname さんがあなたの投稿に返信しました。', 'postId': widget.postId, 'isRead': false, 'timestamp': FieldValue.serverTimestamp() });
    }
  }

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
                  _buildMenuOption(icon: Icons.photo_outlined, label: '画像', onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('画像添付は準備中です')));
                  }),
                  _buildMenuOption(icon: Icons.videocam_outlined, label: '動画', onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('動画添付は準備中です')));
                  }),
                  _buildMenuOption(icon: Icons.mic_none, label: '音声', onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ボイスメッセージは準備中です')));
                  }),
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
    return Scaffold(
      appBar: AppBar(title: const Text('投稿詳細')),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildPostContent()),
                const SliverToBoxAdapter(child: Divider(height: 1)),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('コメント', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                _buildCommentsList(),
              ],
            ),
          ),
          _buildCommentInputField(),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('posts').doc(widget.postId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        if (!snapshot.data!.exists) return const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('投稿が見つかりません。')));
        final data = snapshot.data!.data() as Map<String, dynamic>;
        return _PostCard(postData: data);
      },
    );
  }

  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('comments').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        if (snapshot.hasError) {
          print("コメント読み込みエラー: ${snapshot.error}");
          return SliverToBoxAdapter(child: Center(child: Text("コメントの読み込みに失敗しました:\n${snapshot.error}", textAlign: TextAlign.center)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('まだコメントはありません。'))));
        final comments = snapshot.data!.docs;
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final commentData = comments[index].data() as Map<String, dynamic>;
              return _CommentTile(commentData: commentData);
            },
            childCount: comments.length,
          ),
        );
      },
    );
  }
  
  Widget _buildCommentInputField() {
    final bool canComment = _postAuthorId != null;
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border(top: BorderSide(color: Colors.grey.shade200))),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: Colors.grey.shade600,
                onPressed: _showAttachmentMenu,
              ),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(hintText: 'コメントを追加...', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16.0)),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send_rounded, color: canComment ? Theme.of(context).colorScheme.primary : Colors.grey),
                onPressed: canComment ? _addComment : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> postData;
  const _PostCard({required this.postData});

  @override
  Widget build(BuildContext context) {
    final String postUserId = postData['userId'];
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(postUserId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox.shrink();
        final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        final profileImageUrl = userData['imageUrl'];
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null, child: profileImageUrl == null ? const Icon(Icons.person) : null),
                  const SizedBox(width: 12),
                  Text(userData['nickname'] ?? '...', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 16),
              Text(postData['content'] ?? '', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.6)),
            ],
          ),
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> commentData;
  const _CommentTile({required this.commentData});

  @override
  Widget build(BuildContext context) {
    final String commentUserId = commentData['userId'] ?? '';
    if (commentUserId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(commentUserId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) return const ListTile(title: Text("読み込み中..."));
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) return const SizedBox.shrink();
        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final profileImageUrl = userData['imageUrl'];

        return ListTile(
          leading: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: commentUserId))),
            child: CircleAvatar(backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null, child: profileImageUrl == null ? const Icon(Icons.person) : null),
          ),
          title: Text(userData['nickname'] ?? '...', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(commentData['text'] ?? ''),
        );
      },
    );
  }
}