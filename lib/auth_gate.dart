import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Firebaseの認証状態の変更を監視するStream
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // まだ接続が完了していない場合は、ローディング表示
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // ログイン状態（Userオブジェクトが存在する）かチェック
        if (snapshot.hasData) {
          // ログイン済みの場合：HomeScreenを表示
          return const HomeScreen();
        } else {
          // 未ログインの場合：WelcomeScreenを表示
          return const WelcomeScreen();
        }
      },
    );
  }
}