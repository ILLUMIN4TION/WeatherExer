// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:weathexer/screens/main_navigation.dart';
import 'package:weathexer/services/character_service.dart';
import 'package:weathexer/viewmodels/chat_view_model.dart';

void main() async {
  // 1. 환경변수 로드 (.env 파일)
  await dotenv.load(fileName: '.env');
  
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
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CharacterService()),
          ChangeNotifierProvider(create: (_) => ChatViewModel()),
        ],
        child: const MainNavigation(),
      ),
    );
  }
}
