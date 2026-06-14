// lib/screens/main_navigation.dart
import 'package:flutter/material.dart';
import 'home/home_screen.dart'; // 홈 화면 import

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // 4개의 탭 리스트
  final List<Widget> _screens = [
    const HomeScreen(), // 1번 탭: 방금 만든 홈 화면
    const Center(child: Text('탭 2: 운동 (대시보드)', style: TextStyle(fontSize: 24))),
    const Center(child: Text('탭 3: 수집 및 상점', style: TextStyle(fontSize: 24))),
    const Center(child: Text('탭 4: 설정', style: TextStyle(fontSize: 24))),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: '운동'),
          BottomNavigationBarItem(icon: Icon(Icons.star_rounded), label: '수집'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}