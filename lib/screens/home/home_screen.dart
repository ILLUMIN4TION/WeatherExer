import 'package:flutter/material.dart';
// 아까 만든 타이프라이터 위젯과 모델을 import 해줘 (경로는 본인 프로젝트에 맞게 확인)
import '../../widgets/custom/typewriter_text.dart';
import '../../models/character_info.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 임시 캐릭터 데이터 생성
  final CharacterInfo dummyCharacter = CharacterInfo(
    name: "트레이너",
    blipSoundPath: "assets/audio/sound_effect/blip.wav", // 여기에 본인이 넣은 파일명 입력!
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 배경색은 전체 테마를 따라가지만 명시적으로 다크하게 설정
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            // 1. 상단: 날씨 정보 (임시)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "📍 부천시",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text("☀️ 24°C", style: TextStyle(fontSize: 18)),
                ],
              ),
            ),

            // 2. 중앙: 캐릭터 임시 플레이스홀더 (도형)
            Expanded(
              child: Center(
                child: Container(
                  width: 200,
                  height: 350,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00E676),
                      width: 2,
                    ), // 민트색 테두리
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 80,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "${dummyCharacter.name} (임시)",
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. 하단: 대화창 및 타이프라이터 텍스트
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: double.infinity,
                // 🔥 수정된 부분: minHeight 대신 constraints 속성 사용
                constraints: const BoxConstraints(minHeight: 100),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: TypewriterText(
                  text: "오늘 날씨가 꽤 쌀쌀하네!\n겉옷은 잘 챙겼어? 나랑 같이 운동하자.",
                  soundPath: dummyCharacter.blipSoundPath,
                  speed: 40,
                  textStyle: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10), // 하단 네비게이션 바와의 간격
          ],
        ),
      ),
    );
  }
}
