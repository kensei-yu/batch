import 'package:batch/screens/profile_setup_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
          final user = snapshot.data!;
          // ユーザーのプロフィール情報を監視するStream
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                final isProfileSetupComplete = userData?['isProfileSetupComplete'] ?? false;

                if (isProfileSetupComplete == true) {
                  return const HomeScreen();
                } else {
                  return const ProfileSetupScreen();
                }
              } else {
                // ユーザードキュメントがない場合もプロフィール設定へ
                return const ProfileSetupScreen();
              }
            },
          );
        } else {
          // 未ログインの場合：WelcomeScreenを表示
          return const WelcomeScreen();
        }
      },
    );
  }
}