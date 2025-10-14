// lib/screens/match_dialog.dart


import 'dart:convert';
import 'package:flutter/material.dart';
import 'chat_screen.dart';

// URLかBase64かを判定してImageProviderを返すヘルパー
ImageProvider? _getImageProvider(String? data) {
  if (data == null || data.isEmpty) return null;
  if (data.startsWith('http')) return NetworkImage(data);
  try { return MemoryImage(base64Decode(data)); } catch (e) { return null; }
}


void showMatchDialog({
  required BuildContext context,
  required String myImageUrl, // 元のデータ（URL or Base64）を渡す
  required Map<String, dynamic> peerUser,
}) {
  showDialog(
    context: context,
    builder: (context) {
      // ▼▼▼【ここから修正】画像表示部分の変更 ▼▼▼
      final myImageProvider = _getImageProvider(myImageUrl);
      final peerImageProvider = _getImageProvider(peerUser['imageUrl']);
      // ▲▲▲【ここまで修正】▲▲▲

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "IT'S A MATCH!",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.pinkAccent),
              ),
              const SizedBox(height: 16),
              Text(
                '${peerUser['nickname'] ?? '相手'}さんとマッチしました！',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: myImageProvider,
                    child: myImageProvider == null ? const Icon(Icons.person, size: 40) : null,
                  ),
                  const SizedBox(width: 16),
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: peerImageProvider,
                    child: peerImageProvider == null ? const Icon(Icons.person, size: 40) : null,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => ChatScreen(peerUser: {
                        'uid': peerUser['uid'],
                        'nickname': peerUser['nickname'],
                        'imageUrl': peerUser['imageUrl'],
                      }),
                    ));
                  },
                  child: const Text('メッセージを送る'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('続ける'),
              ),
            ],
          ),
        ),
      );
    },
  );
}