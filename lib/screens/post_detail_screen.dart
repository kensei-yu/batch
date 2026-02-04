// lib/screens/post_detail_screen.dart


import 'dart:io';
import 'package:batch/screens/user_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;


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
  
  File? _commentImageFile;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchPostAuthor();
  }
  
  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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

  Future<void> _pickImageForComment() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() => _commentImageFile = File(pickedFile.path));
    }
  }
  
  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty && _commentImageFile == null) return;
    if (_postAuthorId == null || _currentUser == null) return;

    setState(() { _isSending = true; });

    try {
      String? imageUrl;
      if (_commentImageFile != null) {
        final fileName = DateTime.now().millisecondsSinceEpoch.toString() + path.extension(_commentImageFile!.path);
        final ref = FirebaseStorage.instance.ref('comment_images/${widget.postId}/${_currentUser!.uid}/$fileName');
        await ref.putFile(_commentImageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      final commentText = _commentController.text.trim();
      final newCommentRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('comments').doc();
      
      await newCommentRef.set({
        'id': newCommentRef.id,
        'userId': _currentUser!.uid,
        'text': commentText,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp()
      });

      await FirebaseFirestore.instance.collection('posts').doc(widget.postId).update({'commentCount': FieldValue.increment(1)});
      
      _commentController.clear();
      setState(() => _commentImageFile = null);
      FocusScope.of(context).unfocus();

      if (_currentUser!.uid != _postAuthorId) {
        print("DEBUG: Creating reply notification for $_postAuthorId");
        final notificationRef = FirebaseFirestore.instance.collection('users').doc(_postAuthorId!).collection('notifications').doc();
        final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
        final currentUserNickname = currentUserDoc.data()?['nickname'] ?? '誰か';
        await notificationRef.set({
          'id': notificationRef.id,
          'type': 'reply',
          'senderId': _currentUser!.uid,
          'message': '$currentUserNickname さんがあなたの投稿に返信しました。',
          'content': commentText,
          'postId': widget.postId,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp()
        });
        print("DEBUG: Reply notification created");
      } else {
        print("DEBUG: Self-reply, skipping notification");
      }
    } catch (e) {
      print("DEBUG: Error adding comment: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('コメントの送信に失敗しました: $e')));
    } finally {
      if (mounted) setState(() { _isSending = false; });
    }
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
        if (snapshot.hasError) return SliverToBoxAdapter(child: Center(child: Text("コメントの読み込みに失敗しました:\n${snapshot.error}", textAlign: TextAlign.center)));
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
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_commentImageFile != null)
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
                      child: Image.file(_commentImageFile!, fit: BoxFit.cover),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, color: Colors.white, size: 16)),
                      onPressed: () => setState(() => _commentImageFile = null),
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
                    onPressed: _pickImageForComment,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'コメントを追加...',
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        isDense: true
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send_rounded, color: Theme.of(context).colorScheme.primary),
                    onPressed: _isSending || (_commentController.text.trim().isEmpty && _commentImageFile == null) ? null : _addComment,
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

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> postData;
  const _PostCard({required this.postData});

  @override
  Widget build(BuildContext context) {
    final String postUserId = postData['userId'];
    final postImageUrl = postData['imageUrl'] as String?;
    final postContent = postData['content'] ?? '';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(postUserId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox.shrink();
        final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        final profileImageUrl = userData['imageUrl'] as String?;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                    backgroundColor: Colors.grey.shade300,
                    child: profileImageUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 12),
                  Text(userData['nickname'] ?? '...', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              if(postContent.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(postContent, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.6)),
              ],
              if(postImageUrl != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(postImageUrl, fit: BoxFit.cover, width: double.infinity),
                ),
              ]
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

    final commentImageUrl = commentData['imageUrl'] as String?;
    final commentText = commentData['text'] ?? '';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(commentUserId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) return const ListTile(title: Text("読み込み中..."));
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) return const SizedBox.shrink();
        
        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final profileImageUrl = userData['imageUrl'] as String?;

        return ListTile(
          leading: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: commentUserId))),
            child: CircleAvatar(
              backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
              backgroundColor: Colors.grey.shade300,
              child: profileImageUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
            ),
          ),
          title: Text(userData['nickname'] ?? '...', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (commentText.isNotEmpty) Text(commentText),
              if (commentImageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(commentImageUrl, height: 150, width: double.infinity, fit: BoxFit.cover),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}