import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  final String baseUrl = "http://192.168.0.40:8000"; // 실제 로컬 IP로 유지

  /// 백엔드로 메시지와 더미 상황 데이터를 보내고 SSE 스트림을 받아오는 함수
  Stream<Map<String, dynamic>> sendChatMessage(
    String message, {
    // 테스트를 위한 기본 더미 데이터 셋팅
    String location = "경기도 부천시",
    String weather = "비",
    int temp = 15,
    int daysMet = 7,
  }) async* {
    
    // 1. Uri 파서를 이용해 쿼리 파라미터를 안전하게 자동 인코딩해서 조립!
    final uri = Uri.parse(baseUrl).replace(
      path: '/chat',
      queryParameters: {
        'message': message,
        'location': location,
        'weather': weather,
        'temp': temp.toString(), // 쿼리 파라미터는 모두 String 타입이어야 함
        'days_met': daysMet.toString(),
      },
    );

    final request = http.Request('GET', uri);
    final http.Client client = http.Client();

    try {
      final http.StreamedResponse response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('백엔드 연결 실패: 상태 코드 ${response.statusCode}');
      }

      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final String line in stream) {
        if (line.startsWith('data: ')) {
          final String dataString = line.substring(6);
          if (dataString.trim() == "[DONE]") break; // 혹시 모를 완료 시그널 방어
          if (dataString.trim().isEmpty) continue;

          try {
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
    } finally {
      client.close(); // 무조건 통신 종료
    }
  }
}