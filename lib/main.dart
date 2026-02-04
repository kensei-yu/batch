// lib/main.dart


import 'package:batch/auth_gate.dart';
import 'package:batch/firebase_options.dart';
import 'package:batch/screens/home_screen.dart';
import 'package:batch/screens/login_screen.dart';
import 'package:batch/screens/registration_screen.dart';
import 'package:batch/screens/settings_screen.dart';
import 'package:batch/screens/welcome_screen.dart';
import 'package:batch/screens/profile_setup_screen.dart'; // Import added
import 'package:batch/theme_notifier.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart'; // Import restored
import 'package:google_fonts/google_fonts.dart'; // Import added



void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await loadThemeColor(); 
  runApp(const MyApp());

  // スプラッシュ画面を1.5秒間表示し続ける
  await Future.delayed(const Duration(milliseconds: 1500));
  FlutterNativeSplash.remove();
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: themeColorNotifier,
      builder: (context, currentColor, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeModeNotifier,
          builder: (context, currentMode, child) {
            return MaterialApp(
              title: 'BATCH',
              debugShowCheckedModeBanner: false,
              themeMode: currentMode,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: currentColor,
                  brightness: Brightness.light,
                ),
                useMaterial3: true,
                scaffoldBackgroundColor: Colors.grey[50],
                appBarTheme: AppBarTheme(
                  backgroundColor: Colors.grey[50],
                  foregroundColor: Colors.black87,
                  elevation: 0,
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                bottomNavigationBarTheme: BottomNavigationBarThemeData(
                  selectedItemColor: currentColor,
                  unselectedItemColor: Colors.grey,
                  showUnselectedLabels: true,
                  type: BottomNavigationBarType.fixed,
                ),
                cardTheme: CardThemeData(
                  elevation: 1.0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.white,
                  surfaceTintColor: Colors.white,
                ),
                textTheme: GoogleFonts.notoSansJpTextTheme(
                  const TextTheme(
                    bodyLarge: TextStyle(color: Colors.black87),
                    bodyMedium: TextStyle(color: Colors.black87),
                    titleLarge: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                    titleMedium: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: currentColor,
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
                scaffoldBackgroundColor: const Color(0xFF121212),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF121212),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                bottomNavigationBarTheme: BottomNavigationBarThemeData(
                  backgroundColor: const Color(0xFF1E1E1E),
                  selectedItemColor: currentColor,
                  unselectedItemColor: Colors.grey,
                  showUnselectedLabels: true,
                  type: BottomNavigationBarType.fixed,
                ),
                cardTheme: CardThemeData(
                  elevation: 1.0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: const Color(0xFF1E1E1E),
                  surfaceTintColor: const Color(0xFF1E1E1E),
                ),
                textTheme: GoogleFonts.notoSansJpTextTheme(
                  const TextTheme(
                    bodyLarge: TextStyle(color: Colors.white),
                    bodyMedium: TextStyle(color: Colors.white),
                    titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('ja', 'JP'),
              ],
              home: const AuthGate(),
              routes: {
                '/welcome': (context) => const WelcomeScreen(),
                '/login': (context) => const LoginScreen(),
                '/register': (context) => const RegistrationScreen(),
                '/home': (context) => const HomeScreen(),
                '/settings': (context) => const SettingsScreen(),
                '/profile_setup': (context) => const ProfileSetupScreen(),
              },
            );
          },
        );
      },
    );
  }
}