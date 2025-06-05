import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart';
import 'welcome_screen.dart'; // ログアウト後の遷移先

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({Key? key}) : super(key: key);

  @override
  _MyPageScreenState createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true; // ロード開始時にtrueにする
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (mounted) { // ウィジェットがまだツリーにあるか確認
          if (doc.exists) {
            setState(() {
              _userProfile = doc.data();
              _isLoading = false;
            });
          } else {
            // ドキュメントが存在しない場合 (例: Googleログイン直後でFirestoreに未登録など)
            // ここでデフォルトのプロフィールを作成するか、ユーザーに編集を促すこともできる
             setState(() {
              _userProfile = {'email': user.email}; // 最低限メールアドレスは表示
              _isLoading = false;
            });
            print('User document does not exist for UID: ${user.uid}');
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('プロフィール情報の取得に失敗しました: $e')),
          );
        }
      }
    } else {
      // ユーザーがnullの場合 (理論上HomeScreenにいるならログイン済みのはずだが念のため)
       if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getAgeFromBirthDate(Timestamp? birthDateTimestamp) {
    if (birthDateTimestamp == null) return '未設定';
    
    final birthDate = birthDateTimestamp.toDate();
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    
    return age >= 0 ? '${age}歳' : '未設定'; // 年齢が負にならないように
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('マイページ'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              );
              if (result == true && mounted) {
                _loadUserProfile(); 
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userProfile == null && user == null // ユーザー情報もFirebase Authユーザーもnullの場合
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('ユーザー情報が取得できませんでした。'),
                      ElevatedButton(
                        onPressed: () async {
                           await FirebaseAuth.instance.signOut();
                            if(mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                                (route) => false,
                              );
                            }
                        },
                        child: const Text('ログイン画面に戻る'),
                      )
                    ],
                  )
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _userProfile?['imageUrl'] != null
                            ? NetworkImage(_userProfile!['imageUrl'])
                            : null,
                        child: _userProfile?['imageUrl'] == null
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _userProfile?['nickname'] ?? _userProfile?['name'] ?? user?.displayName ?? 'ゲストユーザー',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _userProfile?['email'] ?? user?.email ?? 'メールアドレス未設定',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'プロフィール情報',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildProfileItem(
                                '性別',
                                _userProfile?['gender'] ?? '未設定',
                                Icons.person_outline,
                              ),
                              const Divider(height: 24),
                              _buildProfileItem(
                                '年齢',
                                _getAgeFromBirthDate(_userProfile?['birthDate'] as Timestamp?),
                                Icons.cake_outlined,
                              ),
                              const Divider(height: 24),
                              _buildProfileItem(
                                '自己紹介',
                                _userProfile?['bio']?.toString().isNotEmpty == true ? _userProfile!['bio'] : '未設定',
                                Icons.description_outlined,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                            );
                            if (result == true && mounted) {
                              _loadUserProfile();
                            }
                          },
                          icon: const Icon(Icons.edit_note),
                          label: const Text('プロフィールを編集'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final shouldLogout = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('ログアウト'),
                                content: const Text('ログアウトしてもよろしいですか？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('キャンセル'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('ログアウト', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );

                            if (shouldLogout == true) {
                              await FirebaseAuth.instance.signOut();
                              // Googleサインアウトも必要に応じて実行
                              // final GoogleSignIn googleSignIn = GoogleSignIn();
                              // await googleSignIn.signOut();
                              if (mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                                  (route) => false,
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('ログアウト'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                             textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileItem(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Theme.of(context).primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}