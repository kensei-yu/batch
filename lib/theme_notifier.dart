// lib/theme_notifier.dart


import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// アプリのどこからでもアクセスできる、テーマカラーの状態を保持する「通知役」
final ValueNotifier<Color> themeColorNotifier = ValueNotifier(const Color(0xFFF8828E));
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system); // デフォルトはシステム設定

// 保存された色とモードを読み込み、通知役を更新する関数
Future<void> loadThemeColor() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('themeColor');
    if (colorValue != null) {
      themeColorNotifier.value = Color(colorValue);
    }
    
    final modeString = prefs.getString('themeMode');
    if (modeString != null) {
      themeModeNotifier.value = ThemeMode.values.firstWhere(
        (e) => e.toString() == modeString,
        orElse: () => ThemeMode.system,
      );
    }
  } catch (e) {
    print("Failed to load theme settings: $e");
  }
}

// 新しい色を通知役にセットし、アプリ内に保存する関数
Future<void> saveThemeColor(Color color) async {
  themeColorNotifier.value = color; // 状態を更新してリスナーに通知
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeColor', color.value);
  } catch (e) {
    print("Failed to save theme color: $e");
  }
}

// 新しいテーマモードを通知役にセットし、保存する関数
Future<void> saveThemeMode(ThemeMode mode) async {
  themeModeNotifier.value = mode;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.toString());
  } catch (e) {
    print("Failed to save theme mode: $e");
  }
}
