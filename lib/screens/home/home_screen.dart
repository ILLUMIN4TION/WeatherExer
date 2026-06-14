import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart'; // 💡 물리 시뮬레이션을 위해 필수!

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  Offset _releaseOffset = Offset.zero; // 손을 뗀 순간의 좌표 저장용
  late AnimationController _springController;

  final String _basePath = 'assets/characters/huge_breasts/summer_clear';

  @override
  void initState() {
    super.initState();
    // 애니메이션 시간(Duration)을 조절해서 튕기는 길이를 정할 수 있어
    _springController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    
    _springController.addListener(() {
      setState(() {
        // 1.0 에서 0.0 으로 줄어드는 컨트롤러 값을 곱해서 쫀득하게 원점 복귀!
        _dragOffset = _releaseOffset * _springController.value;
      });
    });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        // 1. 크리타 이미지 비율(1200/1216)로 캔버스를 고정! (레터박스 방지)
        child: AspectRatio(
          aspectRatio: 1200 / 1216,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              return Stack(
                fit: StackFit.expand, // 꽉 채우기
                children: [
                  // 레이어 1: 바탕 몸통
                  Image.asset('$_basePath/base.PNG', fit: BoxFit.cover),

                  // 레이어 2: 출렁이는 가슴 파츠 (형태 유지 + 윗부분 고정 변형)
                  // 레이어 2: 출렁이는 가슴 파츠 (윗선 완벽 고정)
Transform(
  // 🔥 핵심: 0.35라는 수치를 네 이미지에 맞게 깎아야 해!
  // 0.0은 이미지 맨 위, 1.0은 맨 아래야. 
  // 캐릭터의 쇄골/가슴 윗선이 전체 이미지 높이의 약 30~40% 지점에 있을 테니 임시로 0.35를 줬어.
  alignment: FractionalOffset(0.5, 0.35), 
  transform: Matrix4.identity()
    // 좌우(X축) 왜곡: 윗선(0.35 지점)은 가만히 있고 아래쪽만 좌우로 흔들림
    ..setEntry(0, 1, (_dragOffset.dx * 0.005).clamp(-0.15, 0.15))
    // 상하(Y축) 늘림: 윗선(0.35 지점)은 고정된 채 아래쪽으로만 쭈욱 늘어남
    ..scale(1.0, (1.0 + _dragOffset.dy * 0.003).clamp(0.8, 1.3)),
  child: Image.asset(
    '$_basePath/breasts.PNG',
    fit: BoxFit.cover,
  ),
),

                  // 레이어 3: 왼팔 파츠
                  Image.asset('$_basePath/hand.PNG', fit: BoxFit.cover),

                  // 🚨 레이어 4: [눈에 보이는 히트박스] 이 안에서만 드래그 가능!
                  Positioned(
                    // 빨간 박스가 가슴 위에 오도록 위치와 크기를 조절해 (비율 기반)
                    left: w * 0.25,  // 가로 시작점
                    top: h * 0.45,   // 세로 시작점 (가슴 윗선 근처)
                    width: w * 0.5,  // 박스 너비
                    height: h * 0.25,// 박스 높이
                    
                    child: GestureDetector(
                      // 터치, 드래그 로직 (이전의 isValidHit 검사가 필요 없어짐!)
                      onPanDown: (_) {
      _springController.stop(); // 누르면 튕기던 거 멈춤
    },
    onPanUpdate: (details) {
      setState(() {
        _dragOffset += details.delta * 0.6; // 당길 때의 저항감
      });
    },
    onPanEnd: (details) {
      // 손을 떼는 순간, 현재 늘어난 거리를 저장하고 1.0부터 0.0으로 고무줄 애니메이션 시작!
      _releaseOffset = _dragOffset;
      _springController.value = 1.0;
      _springController.animateTo(0.0, curve: Curves.elasticOut); 
    },
                      
                      child: Container(
                        // 🛑 여기서 빨간 박스를 눈으로 보면서 위의 left, top, width, height 수치를 맞춰!
                        // 완벽하게 가슴을 덮도록 수치를 찾은 뒤엔, 색상을 Colors.transparent 로 바꾸면 끝!
                        color: Colors.red.withOpacity(0.4), 
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// 🧮 X축과 Y축 스프링 물리를 동시에 결합해 주는 벡터 시뮬레이터 클래스
class _VectorSpringSimulation extends Simulation {
  final SpringSimulation xSim;
  final SpringSimulation ySim;

  _VectorSpringSimulation(this.xSim, this.ySim);

  @override
  double x(double time) => 0.0; // 사용 안 함

  @override
  double dx(double time) => 0.0; // 사용 안 함

  @override
  bool isDone(double time) => xSim.isDone(time) && ySim.isDone(time);

  // 이 함수가 오프셋 오브젝트 자체를 매 타임 프레임마다 변환해서 넘겨줘
  @override
  dynamic Image(double time) {
    return Offset(xSim.x(time), ySim.x(time));
  }
  
  // 내부 형변환 매칭 오류 방지용 캐스팅 오버라이드
  @override
  double getPosition(double time) => 0.0;
  @override
  double getVelocity(double time) => 0.0;
}