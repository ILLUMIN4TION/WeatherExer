import 'package:flutter/material.dart';
import 'package:weathexer/services/chat_service.dart';
import 'package:weathexer/services/audio_service.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final AudioQueueService _audioService = AudioQueueService();

  String _currentAiText = "무엇이든 물어보세요!";
  String get currentAiText => _currentAiText;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int? _lastPlayedIndex;
  
  // 🔥 핵심 수정: 네트워크 통신 세션과 타이핑 애니메이션 세션을 완벽히 분리합니다.
  int _chatSessionId = 0; 
  int _typingAnimationId = 0; 

  ChatViewModel() {
    _audioService.player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index != _lastPlayedIndex) {
        _lastPlayedIndex = index;
        
        final sequence = _audioService.player.sequence;
        if (sequence != null && index < sequence.length) {
          // 워밍업 소스(AudioSource.uri, tag 미지정)는 tag가 null → as String 캐스트가
          // 'Null is not a subtype of String' 예외를 일으키던 문제.
          // 안전 캐스트: null/비어있는 tag(워밍업 등)는 타이핑 애니메이션을 스킵한다.
          final tag = sequence[index].tag;
          if (tag is String && tag.isNotEmpty) {
            _playTypingAnimation(tag);
          }
        }
      }
    });
  }

  /// [location]: 현재 위치 (예: "경기도 부천시")
  /// [weather]: 현재 날씨 (예: "맑음", "비")
  Future<void> sendMessage(
    String message, {
    String location = '현재 위치',
    String weather = '맑음',
  }) async {
    if (message.trim().isEmpty) return;

    _isLoading = true;
    notifyListeners();

    _chatService.cancelActiveStream();
    _chatSessionId++;
    _typingAnimationId++;
    final int currentChatSession = _chatSessionId;

    await _audioService.clearQueue();

    _currentAiText = "";
    _lastPlayedIndex = null;
    notifyListeners();

    try {
      final chatStream = _chatService.sendChatMessage(
        message,
        location: location,
        weather: weather,
      );

      await for (final chunk in chatStream) {
        // 🔥 스트림 전용 방어막: 오직 사용자가 새 질문을 보냈을 때만 통신을 끊음
        if (currentChatSession != _chatSessionId) {
          print("오래된 스트림 청크 버림");
          break; 
        }

        final String textChunk = chunk['text'] ?? "";
        final String audioBase64 = chunk['audio'] ?? "";
        
        if (audioBase64.isNotEmpty && audioBase64.length > 50) { 
          await _audioService.addAudioChunk(audioBase64, textChunk);
        }
      }
    } catch (e) {
      if (currentChatSession == _chatSessionId) {
        _currentAiText = "네트워크 연결에 문제가 발생했습니다.";
        notifyListeners();
      }
    } finally {
      if (currentChatSession == _chatSessionId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _playTypingAnimation(String text) async {
    // 🔥 애니메이션 전용 ID 사용 (이제 네트워크 통신을 강제로 끊지 않습니다!)
    _typingAnimationId++; 
    final int currentAnimationId = _typingAnimationId; 
    
    if (_currentAiText.isNotEmpty) {
      _currentAiText += " ";
    }

    for (int i = 0; i < text.length; i++) {
      if (currentAnimationId != _typingAnimationId) break; 
      
      _currentAiText += text[i];
      notifyListeners(); 
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  @override
  void dispose() {
    _chatService.cancelActiveStream();
    // 🔥 오디오 청크 파일 전체 정리 (메모리 누수 방지)
    _audioService.disposeAll();
    super.dispose();
  }
}
