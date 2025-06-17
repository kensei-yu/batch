// lib/theme_notifier.dart
// このファイルを新しく作成してください。

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// アプリのどこからでもアクセスできる、テーマカラーの状態を保持する「通知役」
final ValueNotifier<Color> themeColorNotifier = ValueNotifier(const Color(0xFFF8828E));

// 保存された色を読み込み、通知役を更新する関数
Future<void> loadThemeColor() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('themeColor');
    if (colorValue != null) {
      themeColorNotifier.value = Color(colorValue);
    }
  } catch (e) {
    print("Failed to load theme color: $e");
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