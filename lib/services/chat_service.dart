import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ChatService {
  // 🔥 .env에서 BACKEND_URL 로드 (기본값: 192.168.0.40:8000)
  final String baseUrl = dotenv.env['BACKEND_URL'] ?? "http://192.168.0.40:8000"; 
  
  // 🔥 StreamedResponse를 저장하여 stream 자체를 직접 종료할 수 있게 관리
  http.StreamedResponse? _activeResponse;
  
  // 🔥 스트림 취소 여부 추적 플래그 (중복 호출 방지)
  bool _isCancelled = false;

  /// 🔥 기존 진행 중인 SSE 통신을 안전하게 완전히 종료
  void cancelActiveStream() {
    if (_isCancelled) return; // 이미 취소되었으면 중복 작업 Skip
    _isCancelled = true;

    if (_activeResponse != null) {
      final response = _activeResponse!;
      
      // 🔥 핵심: stream을 직접 cancel()하면 구독자가 자동으로 정리됨
      // 참고: stream이 이미 소비/완료된 상태일 수 있음 (단일구독) → StateError
      try {
        response.stream.listen(null).cancel(); // listen(null)은 데이터 무시, cancel()은 스트림 종료
      } catch (_) {
        // 이미 소비/완료됨 → 해제할 대상 없음
      }
      
      _activeResponse = null;
    }
  }

  /// 🔥 새 스트림 세션 시작 전 기존 세션 초기화
  void resetSession() {
    cancelActiveStream();
    _isCancelled = false; // 다음 세션을 위해 플래그 리셋
  }

  // 백엔드와 통신하는 진짜 함수
  Stream<Map<String, dynamic>> sendChatMessage(
    String message, {
    String location = "경기도 부천시",
    String weather = "비",
  }) async* {
    // 🔥 이전 세션 완전히 초기화
    resetSession();
    
    final uri = Uri.parse('$baseUrl/chat');
    
    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json; charset=UTF-8';
    request.body = jsonEncode({
      'user_message': message,
      'location': location,
      'weather_condition': weather,
    });

    try {
      final response = await http.Client().send(request);
      _activeResponse = response;
      _isCancelled = false; // 새 스트림 시작 플래그 리셋

      if (response.statusCode != 200) {
        cancelActiveStream();
        throw Exception('백엔드 연결 실패: 상태 코드 ${response.statusCode}');
      }

      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final String line in stream) {
        // 🔥 취소 플래그 체크: 사용자가 새 질문을 보냈다면 즉시 중단
        if (_isCancelled) {
          print("🛑 스트림 수동 취소됨");
          break;
        }
        
        if (line.startsWith('data: ')) {
          final String dataString = line.substring(6);
          if (dataString.trim() == "[DONE]") {
            print("✅ SSE 통신 완료 ([DONE] 수신)");
            break;
          }
          if (dataString.trim().isEmpty) continue;

          try {
            final Map<String, dynamic> jsonData = jsonDecode(dataString);
            yield jsonData; 
          } catch (e) {
            print('JSON 파싱 에러: $e');
          }
        }
      }
    } catch (e) {
      print('SSE 통신 종료 또는 에러 발생: $e');
    } finally {
      // 🔥 수정: 이미 소비된 스트림에 drain() 호출 금지
      // (소비된 단일구독 스트림에 drain()하면 StateError가 발생하여
      //  뷰모델 catch로 전파되고 "네트워크 연결에 문제가 발생했습니다."로 오표시됨)
      cancelActiveStream();
    }
  }
}
