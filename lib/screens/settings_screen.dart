// lib/screens/settings_screen.dart


import 'package:batch/screens/privacy_policy_screen.dart';
import 'package:batch/screens/terms_screen.dart';
import 'package:batch/theme_notifier.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:package_info_plus/package_info_plus.dart'; // ▼▼▼ 追加 ▼▼▼

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '...'; // バージョン情報用の変数

  @override
  void initState() {
    super.initState();
    _loadVersionInfo(); // バージョン情報を読み込む
  }

  // ▼▼▼【追加】アプリのバージョン情報を読み込むメソッド ▼▼▼
  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  void _pickColor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow taller sheets
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        // Color Definitions
        final pinks = [
          Colors.pink,
          const Color(0xFFFF00FF), // Magenta
          Colors.purple,
        ];
        final warms = [
          Colors.red,
          Colors.orange,
          Colors.yellow,
        ];
        final cools = [
          Colors.lightGreen,
          Colors.green,
          Colors.cyan,
          Colors.blue,
        ];

        Widget buildColorSection(String title, List<Color> colors) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 16,
                children: colors.map((color) {
                  final isSelected = themeColorNotifier.value.value == color.value;
                  return GestureDetector(
                    onTap: () {
                      saveThemeColor(color);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 30)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'テーマカラーを選択',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 32),
                  buildColorSection('ピンク・パープル系', pinks),
                  buildColorSection('レッド・イエロー系', warms),
                  buildColorSection('グリーン・ブルー系', cools),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _pickThemeMode() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('外観モードを選択'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                saveThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('システム設定に従う'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                saveThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('ライトモード'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                saveThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('ダークモード'),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // ▼▼▼【修正】ログアウト処理をこのファイルに集約 ▼▼▼
  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしてもよろしいですか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ログアウト', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (shouldLogout == true && mounted) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
    }
  }

  // ▼▼▼【追加】アカウント削除の処理 ▼▼▼
  Future<void> _deleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アカウントを削除'),
        content: const Text('アカウントを完全に削除します。この操作は元に戻せません。本当に続けますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除する', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      try {
        await FirebaseAuth.instance.currentUser?.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('アカウントを削除しました。')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('この操作を行うには、再ログインが必要です。')),
          );
           // 再ログインを促した後、再度この処理を実行させるのが親切
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('アカウントの削除に失敗しました: ${e.message}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('予期しないエラーが発生しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: <Widget>[
          // --- アカウントセクション ---
          _SettingsSectionHeader(title: 'アカウント'),
          _SettingsListItem(
            icon: Icons.lock_outline,
            title: 'パスワードを変更',
            onTap: () {
              // TODO: パスワード変更画面を作成して遷移
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('この機能は現在準備中です。')),
              );
            },
          ),
          _SettingsListItem(
            icon: Icons.delete_forever_outlined,
            title: 'アカウントを削除',
            color: Colors.red,
            onTap: _deleteAccount,
          ),
          const Divider(height: 32),

          // --- アプリ設定セクション ---
          _SettingsSectionHeader(title: 'アプリ設定'),
          ValueListenableBuilder<Color>(
            valueListenable: themeColorNotifier,
            builder: (context, currentColor, child) {
              return _SettingsListItem(
                icon: Icons.color_lens_outlined,
                title: 'テーマカラー',
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
                onTap: _pickColor,
              );
            },
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, currentMode, child) {
              return _SettingsListItem(
                icon: Icons.brightness_6_outlined,
                title: '外観モード',
                trailing: Text(
                  currentMode == ThemeMode.system
                      ? 'システム'
                      : currentMode == ThemeMode.light
                          ? 'ライト'
                          : 'ダーク',
                  style: const TextStyle(color: Colors.grey),
                ),
                onTap: _pickThemeMode,
              );
            },
          ),
          const Divider(height: 32),

          // --- アプリ情報セクション ---
          _SettingsSectionHeader(title: 'このアプリについて'),
          _SettingsListItem(
            icon: Icons.description_outlined,
            title: '利用規約',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
          ),
          _SettingsListItem(
            icon: Icons.shield_outlined,
            title: 'プライバシーポリシー',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
          ),
          _SettingsListItem(
            icon: Icons.code_outlined,
            title: 'オープンソースライセンス',
            onTap: () => showLicensePage(context: context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.grey),
            title: const Text('バージョン'),
            trailing: Text(_version),
          ),
          const Divider(height: 32),

          // --- ログアウト ---
          _SettingsListItem(
            icon: Icons.logout,
            title: 'ログアウト',
            color: Colors.red,
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}


// ▼▼▼【追加】設定項目のためのカスタムウィジェット ▼▼▼
class _SettingsListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsListItem({
    required this.icon,
    required this.title,
    this.color,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = color ?? Theme.of(context).textTheme.bodyLarge?.color;
    final iconColor = color ?? Colors.grey.shade600;
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: titleColor)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String title;
  const _SettingsSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}