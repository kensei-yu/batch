// lib/screens/post_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;


class PostScreen extends StatefulWidget {
  const PostScreen({Key? key}) : super(key: key);

  @override
  _PostScreenState createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final TextEditingController _postController = TextEditingController();
  bool _isPosting = false;
  File? _imageFile;

  Future<void> _pickImage() async {
    if (_isPosting) return;
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitPost() async {
    if (_postController.text.trim().isEmpty && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿内容を入力するか、画像を選択してください。')),
      );
      return;
    }

    setState(() { _isPosting = true; });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _isPosting = false; });
      return;
    }

    try {
      String? imageUrl;
      if (_imageFile != null) {
        final fileName = DateTime.now().millisecondsSinceEpoch.toString() + path.extension(_imageFile!.path);
        final ref = FirebaseStorage.instance.ref('post_images/${user.uid}/$fileName');
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'content': _postController.text.trim(),
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0,
      });

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投稿に失敗しました: $e')),
        );
      }
    } finally {
      if(mounted) setState(() { _isPosting = false; });
    }
  }
  
  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isPosting ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text('新規投稿'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton(
              onPressed: _isPosting ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('投稿する'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _postController,
                autofocus: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '音楽の輪を広げよう',
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ),
          if (_imageFile != null) _buildImagePreview(),
          const Divider(height: 1),
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Container(
            height: 150,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.file(_imageFile!, fit: BoxFit.cover),
          ),
          IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, color: Colors.white, size: 18),
            ),
            onPressed: () => setState(() => _imageFile = null),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.photo_outlined, color: Theme.of(context).colorScheme.primary),
            onPressed: _pickImage,
            tooltip: '画像を選択',
          ),
        ],
      ),
    );
  }
}