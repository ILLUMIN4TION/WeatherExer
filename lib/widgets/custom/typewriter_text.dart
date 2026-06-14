import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class TypewriterText extends StatefulWidget {
  final String text;
  final String soundPath;
  final TextStyle? textStyle;
  final int speed; // 기본 타건 속도 (ms)

  const TypewriterText({
    super.key,
    required this.text,
    required this.soundPath,
    this.textStyle,
    this.speed = 40,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = "";
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isTyping = true; // 화면이 넘어갔을 때 타이핑을 중지하기 위한 플래그

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
    _startTyping();
  }

  // Timer.periodic 대신 비동기 함수(async)로 변경!
  Future<void> _startTyping() async {
    for (int i = 0; i < widget.text.length; i++) {
      // 위젯이 화면에서 사라졌거나 타이핑이 끝났으면 루프 종료
      if (!mounted || !_isTyping) break; 

      setState(() {
        _displayedText += widget.text[i];
      });

      String currentChar = widget.text[i];
      int currentDelay = widget.speed; // 기본 속도 40ms
      bool shouldPlaySound = true;

      // 1. 문자에 따른 호흡(딜레이) 및 사운드 조절
      if (currentChar == ' ' || currentChar == '\n') {
        shouldPlaySound = false;
        // 띄어쓰기는 딜레이 그대로
      } else if (['.', '?', '!'].contains(currentChar)) {
        shouldPlaySound = false; // 구두점에서는 소리 안 남
        currentDelay = 500;      // 마침표 등은 0.5초(500ms) 크게 쉼
      } else if (currentChar == ',') {
        shouldPlaySound = false;
        currentDelay = 250;      // 쉼표는 0.25초 살짝 쉼
      }

      // 2. 효과음 재생
      if (shouldPlaySound) {
        _audioPlayer.play(AssetSource(widget.soundPath.replaceFirst('assets/', '')));
      }

      // 3. 계산된 시간만큼 대기 (UI를 멈추지 않고 비동기적으로 대기함)
      await Future.delayed(Duration(milliseconds: currentDelay));
    }
  }

  @override
  void dispose() {
    _isTyping = false; // 루프 안전 종료
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.textStyle ?? const TextStyle(fontSize: 16, color: Colors.white),
    );
  }
}