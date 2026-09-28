import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/utils/kma_converter.dart';

/// 날씨 상태 enum
enum WeatherCondition {
  clear('맑음', 'clear'),
  rain('비', 'rain'),
  snow('눈', 'snow'),
  cloudy('구름', 'cloudy');

  final String korean;
  final String code;
  const WeatherCondition(this.korean, this.code);
}

/// 위치 정보 모델
class LocationInfo {
  final String city;
  final String fullAddress;
  final double latitude;
  final double longitude;

  const LocationInfo({
    required this.city,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
  });
}

/// 날씨 정보 모델
class WeatherInfo {
  final LocationInfo location;
  final WeatherCondition condition;
  final double temperature;

  const WeatherInfo({
    required this.location,
    required this.condition,
    required this.temperature,
  });

  String get conditionKorean => condition.korean;
  String get conditionCode => condition.code;
}

/// 날씨 서비스 - 실제 API 연동 준비용
class WeatherService {
  static const _kmaApiKey = String.fromEnvironment(
    'KMA_API_KEY',
    defaultValue: '',
  );
  
  /// .env에서 API 키 로드
  String get apiKey => dotenv.get('KMA_API_KEY', fallback: '');

  /// 위치 권한 확인
  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    return permission != LocationPermission.deniedForever;
  }

  /// 현재 위치 가져오기
  Future<Position?> getCurrentPosition() async {
    if (!await _checkLocationPermission()) return null;
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// 현재 날씨 조회 (기상청 단기예보 API)
  Future<WeatherInfo> getWeather() async {
    try {
      final position = await getCurrentPosition();
      final lat = position?.latitude ?? _defaultWeather.location.latitude;
      final lon = position?.longitude ?? _defaultWeather.location.longitude;

      if (apiKey.isEmpty || apiKey.contains('temporary')) {
        print('KMA API key not set, using default weather');
        return _defaultWeather;
      }

      final grid = KmaConverter.latLonToGrid(lat, lon);
      final nx = grid['x']!;
      final ny = grid['y']!;

      final now = DateTime.now();
      final baseDate =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final baseHour = (now.hour ~/ 3) * 3;
      final baseTime = '${baseHour.toString().padLeft(4, '0')}00';
      final encodedKey = Uri.encodeComponent(apiKey);

      final response = await http
          .get(Uri.parse(
            'http://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst'
            '?serviceKey=$encodedKey'
            '&nx=$nx&ny=$ny'
            '&dataType=json'
            '&base_date=$baseDate'
            '&base_time=$baseTime',
          ))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('KMA API HTTP error: ${response.statusCode}');
        return _defaultWeather;
      }

      final data = jsonDecode(response.body);
      final header = data['response']['header'];
      if (header['resultCode'] != '200') {
        print('KMA API result error: ${header['resultMsg']}');
        return _defaultWeather;
      }

      final items = (data['response']['body']['items'] as List?) ?? [];
      double temperature = 0;
      String pty = '0';
      String sky = '1';
      bool gotTemp = false, gotPty = false, gotSky = false;

      for (final item in items) {
        final category = item['category'] as String?;
        final fcstValue = (item['fcstValue'] as num?)?.toString() ?? '';
        if (!gotTemp && category == 'TMP') {
          temperature = double.tryParse(fcstValue) ?? 0;
          gotTemp = true;
        }
        if (!gotPty && category == 'PTY') {
          pty = fcstValue;
          gotPty = true;
        }
        if (!gotSky && category == 'SKY') {
          sky = fcstValue;
          gotSky = true;
        }
      }

      final condition = _determineCondition(pty, sky);
      print('Weather: ${condition.korean} ${temperature.toStringAsFixed(1)}C');

      return WeatherInfo(
        location: LocationInfo(
          city: position != null ? '현재 위치' : '부천시',
          fullAddress: position != null
              ? '위도 ${lat.toStringAsFixed(4)}, 경도 ${lon.toStringAsFixed(4)}'
              : '경기도 부천시',
          latitude: lat,
          longitude: lon,
        ),
        condition: condition,
        temperature: temperature,
      );
    } catch (e) {
      print('Weather fetch failed: $e');
      return _defaultWeather;
    }
  }

  /// PTY + SKY에서 날씨 상태 결정
  /// PTY: 0=없음, 1=비, 2=비/눈, 3=눈
  /// SKY: 1=맑음, 2=구름조금, 3=구름많음, 4=흐림
  WeatherCondition _determineCondition(String pty, String sky) {
    if (pty == '1' || pty == '2') return WeatherCondition.rain;
    if (pty == '3') return WeatherCondition.snow;
    if (sky == '1') return WeatherCondition.clear;
    return WeatherCondition.cloudy;
  }

  /// 개발 중 기본 날씨 값
  static const _defaultWeather = WeatherInfo(
    location: LocationInfo(
      city: '부천시',
      fullAddress: '경기도 부천시',
      latitude: 37.4979,
      longitude: 126.7831,
    ),
    condition: WeatherCondition.clear,
    temperature: 23.0,
  );

  /// 시즌 반환
  String getSeason() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    if (month >= 9 && month <= 11) return 'autumn';
    return 'winter';
  }
}