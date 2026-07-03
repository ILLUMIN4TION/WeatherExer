import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:weathexer/services/chat_service.dart';
import 'package:flutter/services.dart';
import 'package:weathexer/services/audio_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _partsData;
  late AnimationController _idleController;

  // 🔥 1. 날씨 및 구도 상태를 관리하는 변수 (나중에 ViewModel이나 Provider로 분리될 부분)
  final String _currentSeason = 'spring';
  final String _currentWeather = 'clear';
  final String _currentAngle = 'mid'; // low, mid, high

  final String _characterBasePath =
      'assets/characters/huge_breasts/summer_clear_twintail';

  bool _isLoading = false; 
  final ChatService _chatService = ChatService();
  final AudioQueueService _audioService = AudioQueueService();

  String _currentAiText = "말풍선을 터치해서 대화를 시작해 보세요!";
  bool _isTyping = false;

  // 🔥 버그 해결을 위한 핵심 변수 2개 추가!
  int? _lastPlayedIndex; // 중복 실행 방지용 인덱스 추적기
  int _typingSessionId = 0; // 이전 타이핑 강제 종료용 세션 ID

  void _sendTestMessage() async {
    if (_isLoading) return; 
    _isLoading = true;

    _typingSessionId++; 
    _lastPlayedIndex = null;

    setState(() {
      _currentAiText = "";
      _isTyping = true;
    });

    await _audioService.clearQueue();

    try {
      // 🔥 여기서 원하는 더미 데이터를 마음껏 넣어서 테스트할 수 있어!
      final chatStream = _chatService.sendChatMessage(
        "비가 오는데 방구석에서 운동 뭐할까?",
        location: "경기도 부천시",
        weather: "비",
        temp: 15,
        daysMet: 10, // 만난 지 10일째로 설정!
      );

      await for (final chunk in chatStream) {
        final String textChunk = chunk['text'] ?? "";
        final String audioBase64 = chunk['audio'] ?? "";
        
        if (audioBase64.isNotEmpty && audioBase64.length > 50) { 
          await _audioService.addAudioChunk(audioBase64, textChunk);
        } else if (textChunk.isNotEmpty) {
          print("오디오 없는 텍스트 감지 (무시됨): $textChunk");
        }
      }
    } catch (e) {
      setState(() {
        _currentAiText = "연결 에러가 발생했어 ㅠㅠ";
      });
    } finally {
      _isLoading = false;
      setState(() {
        _isTyping = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPartsData();

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _audioService.player.currentIndexStream.listen((index) {
      // 🔥 핵심 방어 로직: index가 null이 아니고, '이전에 실행한 인덱스와 다를 때만' 실행!
      if (index != null && index >= 0 && index != _lastPlayedIndex) {
        _lastPlayedIndex = index; // 방금 실행한 인덱스 번호 저장
        
        final sequence = _audioService.player.sequence;
        if (sequence != null && index < sequence.length) {
          final textToType = sequence[index].tag as String;
          _playTypingAnimation(textToType);
        }
      }
    });
  }

  // 🔥 타이핑 충돌 방지가 적용된 애니메이션 함수
  void _playTypingAnimation(String text) async {
    _typingSessionId++; // 함수가 호출될 때마다 세션 ID 1 증가
    final int currentSessionId = _typingSessionId; // 현재 세션 고정

    for (int i = 0; i < text.length; i++) {
      // 컴포넌트가 꺼졌거나, 새로운 대화가 시작되어 세션 ID가 달라졌다면 즉시 중단(break)!
      if (!mounted || currentSessionId != _typingSessionId) break;
      
      setState(() {
        _currentAiText += text[i];
      });
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _loadPartsData() async {
    final String jsonString = await rootBundle.loadString(
      '$_characterBasePath/parts_info.json',
    );
    final Map<String, dynamic> data = json.decode(jsonString);
    setState(() {
      _partsData = data;
    });
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  Offset _getBreathingOffset(String partName, double progress) {
    final double t = progress * 2 * math.pi;
    if (partName.contains('bottom') ||
        partName.contains('leg') ||
        partName.contains('foot')) {
      return Offset.zero;
    }
    if (partName.contains('hand') || partName.contains('arm')) {
      return Offset(0, math.sin(t - 0.5) * 3);
    }
    return Offset(0, math.sin(t) * 4.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_partsData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final firstPartInfo = _partsData!.values.first;
    final double canvasW = firstPartInfo['canvas_width'].toDouble();
    final double canvasH = firstPartInfo['canvas_height'].toDouble();

    // 동적으로 배경 이미지 경로 생성
    final String backgroundPath =
        'assets/backgrounds/$_currentSeason/${_currentWeather}_$_currentAngle.png';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      // 🔥 핵심 1: 배경 이미지가 화면 맨 밑끝까지 내려가도록 허용!
      extendBody: true,

      body: Stack(
        fit: StackFit.expand,
        children: [
          // ☁️ [Layer 1] 동적 배경 이미지
          Image.asset(
            backgroundPath,
            fit: BoxFit.cover, // 화면 꽉 차게 비율 유지
            // 에러 처리: 이미지가 없을 경우 임시 색상 표시
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF4A90E2),
              alignment: Alignment.center,
              child: const Text(
                '배경 이미지 없음',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),

          // 💃 [Layer 2] 숨쉬는 L2D 캐릭터
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedBuilder(
              animation: _idleController,
              builder: (context, child) {
                return AspectRatio(
                  aspectRatio: canvasW / canvasH,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      List<Widget> stackChildren = [];

                      _partsData!.forEach((partName, info) {
                        final double x = info['x'].toDouble();
                        final double y = info['y'].toDouble();
                        final double partW = info['width'].toDouble();
                        final double partH = info['height'].toDouble();

                        final Offset currentOffset = _getBreathingOffset(
                          partName,
                          _idleController.value,
                        );

                        double angle = 0.0;
                        Alignment transformAlignment = Alignment.center;

                        if (partName.contains('hair')) {
                          transformAlignment = Alignment.topCenter;
                          final double t = _idleController.value * 2 * math.pi;
                          angle = math.sin(t * 1.5) * 0.03;
                        }

                        stackChildren.add(
                          Positioned(
                            left: w * (x / canvasW),
                            top: h * (y / canvasH),
                            width: w * (partW / canvasW),
                            height: h * (partH / canvasH),
                            child: Transform.translate(
                              offset: currentOffset,
                              child: Transform.rotate(
                                angle: angle,
                                alignment: transformAlignment,
                                child: Image.asset(
                                  '$_characterBasePath/$partName.PNG',
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                          ),
                        );
                      });

                      return Stack(
                        fit: StackFit.expand,
                        children: stackChildren,
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // 💬 [Layer 3] 상단 UI (위치, 온도, 글래스모피즘 말풍선)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 20.0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 좌측: 위치 및 날씨 정보
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '경기도 부천시',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '23°',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 80,
                          fontWeight: FontWeight.w300,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        '맑음',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // 우측: 글래스모피즘 말풍선
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20.0, left: 20.0),
                      // 🔥 말풍선을 터치하면 백엔드 통신 시작!
                      child: GestureDetector(
                        onTap: _isTyping ? null : _sendTestMessage,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: ConstrainedBox(
                                // 🔥 채팅창의 최대 높이를 120 픽셀로 제한
                                constraints: const BoxConstraints(
                                  maxHeight: 120,
                                ),
                                // 🔥 글자를 통째로 투명하게 만들던 ShaderMask 제거
                                child: SingleChildScrollView(
                                  // reverse: true 덕분에 글이 길어지면 항상 맨 아래(최신 대화)로 자동 스크롤됨
                                  reverse: true,
                                  child: Text(
                                    _currentAiText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                    softWrap: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 📊 [Layer 4] 플로팅 아일랜드 스타일 바텀 시트
          Align(
            alignment: Alignment.bottomCenter,
            // 🏝️ 화면 양옆과 아래에 여백을 주어 둥둥 떠다니는 카드 느낌 구현
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                bottom: 100.0,
              ),
              // 🔥 마우스 드래그를 허용하는 마법의 세팅
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: DraggableScrollableSheet(
                  initialChildSize: 0.12,
                  minChildSize: 0.12,
                  maxChildSize: 0.75, // 카드 형태라 화면 끝까지 안 올라가게 제한
                  snap: true,
                  builder:
                      (
                        BuildContext context,
                        ScrollController scrollController,
                      ) {
                        return ClipRRect(
                          // 둥둥 떠있는 느낌을 위해 4면 모두 모서리를 둥글게 처리
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                // ✨ 유리 테두리 빛 반사 효과 (대각선 그라데이션)
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: ListView(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 24,
                                ),
                                children: [
                                  // 드래그 핸들
                                  Center(
                                    child: Container(
                                      width: 40,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  const Text(
                                    "☁️ 상세 날씨 정보", // 아이콘 추가 테스트
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // TODO: 나중에 이 부분을 GridView나 예쁜 아이콘 카드로 바꿀 예정
                                  _buildDummyWeatherInfoTile("체감 온도", "24°"),
                                  _buildDummyWeatherInfoTile("습도", "55%"),
                                  _buildDummyWeatherInfoTile("풍속", "3m/s"),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 임시 정보 타일 위젯 생성기 (클래스 맨 밑에 추가해 줘)
  Widget _buildDummyWeatherInfoTile(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
