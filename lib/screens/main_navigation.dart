import 'package:flutter/material.dart';
// 네가 만든 화면들 import
import 'home/home_screen.dart'; 

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const Center(child: Text('운동', style: TextStyle(color: Colors.white))),
    const Center(child: Text('수집', style: TextStyle(color: Colors.white))),
    const Center(child: Text('설정', style: TextStyle(color: Colors.white))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      // 🔥 핵심 1: 화면 전체를 쓰기 위해 배경 연장
      extendBody: true, 
      
      body: _screens[_currentIndex],
      
      // 🔥 핵심 2: 자연스럽게 녹아드는 비네트 효과 네비게이션 바
      bottomNavigationBar: Container(
        height: 150, // 🔥 높이를 크게 줘서 그라데이션이 길고 아주 부드럽게 풀리도록 설정
        alignment: Alignment.bottomCenter,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.85), // 맨 밑바닥은 아이콘이 보여야 하니 살짝 어둡게
              Colors.black.withOpacity(0.3),  // 중간 지점은 반투명하게 스르륵
              Colors.transparent,             // 위쪽은 완전히 투명해짐
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0), // 아이콘들을 화면 맨 아래쪽으로 살짝 내림
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(Icons.home_rounded, "홈", 0),
                _buildNavItem(Icons.fitness_center_rounded, "운동", 1),
                _buildNavItem(Icons.star_rounded, "수집", 2),
                _buildNavItem(Icons.settings_rounded, "설정", 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 28,
            color: isSelected ? Colors.greenAccent : Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.greenAccent : Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}