import 'package:flutter/material.dart';
import 'chat_screen.dart'; // ChatScreenへ遷移するため

void showMatchDialog({
  required BuildContext context,
  required String myImageUrl,
  required Map<String, dynamic> peerUser,
}) {
  showDialog(
    context: context,
    builder: (context) {
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
                    backgroundImage: myImageUrl.isNotEmpty ? NetworkImage(myImageUrl) : null,
                    child: myImageUrl.isEmpty ? const Icon(Icons.person, size: 40) : null,
                  ),
                  const SizedBox(width: 16),
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: peerUser['imageUrl'] != null ? NetworkImage(peerUser['imageUrl']) : null,
                    child: peerUser['imageUrl'] == null ? const Icon(Icons.person, size: 40) : null,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // ダイアログを閉じる
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