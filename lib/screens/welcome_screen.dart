import 'package:flutter/material.dart';
import 'login_screen.dart'; // LoginScreenをインポート
import 'registration_screen.dart'; // RegistrationScreenをインポート

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.PNG'), // 背景画像パス
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end, // ボタンを画面下部に寄せる
            children: [
              // const Spacer(), // Spacerを削除し、MainAxisAlignment.end で調整
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF8828E),
                    foregroundColor: const Color(0xFFffffff),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  child: const Text('ログイン'),
                ),
              ),
              const SizedBox(height: 16.0),
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFffffff),
                    foregroundColor: const Color(0xFF4D738F),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const RegistrationScreen()),
                    );
                  },
                  child: const Text('新規登録'),
                ),
              ),
              const SizedBox(height: 70.0), // 下部の余白
            ],
          ),
        ),
      ),
    );
  }
}