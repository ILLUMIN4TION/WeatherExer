// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/main_navigation.dart'; // 분리한 네비게이션 파일 import

void main() {
  // 나중에 여기에 Hive 초기화, .env 로드 같은 세팅 로직이 들어갈 자리야!
  runApp(const WeathexerApp());
}

class WeathexerApp extends StatelessWidget {
  const WeathexerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weathexer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00E676), // 포인트 컬러: 네온 민트
        textTheme: GoogleFonts.notoSansKrTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: Color(0xFF00E676),
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: const MainNavigation(), // 시작 화면을 네비게이션으로 지정!
    );
  }
}
