import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  // 🔥 백엔드(PC 1)의 실제 로컬 IP 주소로 변경해야 해!
  // 예: 스마트폰과 PC가 같은 Wi-Fi에 연결되어 있어야 하며, 
  // 에뮬레이터 테스트 시에는 '10.0.2.2', 실제 기기면 '192.168.0.X' 등을 입력.
  final String baseUrl = "http://192.168.0.40:8000";

  /// 백엔드로 메시지를 보내고 실시간 스트림(SSE)을 받아오는 함수
  Stream<Map<String, dynamic>> sendChatMessage(String message) async* {
    // 1. URL 인코딩 및 요청 세팅
    final uri = Uri.parse('$baseUrl/chat?message=${Uri.encodeComponent(message)}');
    final request = http.Request('GET', uri);

    try {
      // 2. 스트리밍 요청 보내기 (일반 get이 아닌 send를 사용)
      final http.Client client = http.Client();
      final http.StreamedResponse response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('백엔드 연결 실패: 상태 코드 ${response.statusCode}');
      }

      // 3. 바이트 스트림 -> UTF-8 디코딩 -> 줄 단위(Line)로 분할
      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      // 4. 들어오는 데이터를 실시간으로 읽기
      await for (final String line in stream) {
        // SSE 규격은 'data: ' 로 시작함
        if (line.startsWith('data: ')) {
          final String dataString = line.substring(6); // 'data: ' 이후의 텍스트만 추출
          
          if (dataString.trim().isEmpty) continue;

          try {
            // JSON으로 파싱하여 { "text": "...", "audio": "Base64..." } 형태로 반환 (yield)
            final Map<String, dynamic> jsonData = jsonDecode(dataString);
            yield jsonData; 
          } catch (e) {
            print('JSON 파싱 에러: $e | 원본 데이터: $dataString');
          }
        }
      }
    } catch (e) {
      print('SSE 통신 중 에러 발생: $e');
      rethrow;
    }
  }
}