import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Firebase設定ファイルをインポート
import 'screens/welcome_screen.dart'; // WelcomeScreenをインポート

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ログイン・新規登録', // アプリのタイトル
      theme: ThemeData(
        primarySwatch: Colors.blue, // アプリのテーマカラー
      ),
      home: const WelcomeScreen(), // 初期画面としてWelcomeScreenを指定
    );
  }
}