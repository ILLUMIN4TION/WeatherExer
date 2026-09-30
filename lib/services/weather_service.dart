import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// 날씨 상태 enum
enum WeatherCondition {
  clear('맑음', 'clear'),
  rain('비', 'rain'),
  snow('눈', 'snow'),
  cloudy('구름', 'cloudy');

  final String korean;
  final String code;
  const WeatherCondition(this.korean, this.code);

  /// 서버가 보내는 condition_code → enum 매핑 (unknown/미상 → clear)
  static WeatherCondition fromCode(String? code) {
    switch (code) {
      case 'rain':
        return WeatherCondition.rain;
      case 'snow':
        return WeatherCondition.snow;
      case 'cloudy':
        return WeatherCondition.cloudy;
      default:
        return WeatherCondition.clear;
    }
  }
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
  final double? feelsLike;
  final int? humidity;
  final double? windSpeed;
  final double? tempMin;
  final double? tempMax;
  final int? precipProbMax;
  final List<DailyForecastInfo> forecast;
  final bool isFallback;

  const WeatherInfo({
    required this.location,
    required this.condition,
    required this.temperature,
    this.feelsLike,
    this.humidity,
    this.windSpeed,
    this.tempMin,
    this.tempMax,
    this.precipProbMax,
    this.forecast = const [],
    this.isFallback = false,
  });

  String get conditionKorean => condition.korean;
  String get conditionCode => condition.code;
}

/// 일별 예보 모델 (오늘 / 내일 / 글피 등)
class DailyForecastInfo {
  final String date;      // "2026-10-01"
  final String label;     // "오늘" | "내일" | "글피" | "10월 3일"
  final String weekday;   // "수"
  final double? tempMin;
  final double? tempMax;
  final String conditionKorean;
  final String conditionCode;
  final int? precipProbMax;

  const DailyForecastInfo({
    required this.date,
    required this.label,
    required this.weekday,
    this.tempMin,
    this.tempMax,
    this.conditionKorean = '',
    this.conditionCode = 'clear',
    this.precipProbMax,
  });
}

/// 날씨 서비스.
///
/// KMA를 직접 호출하지 않고 FastAPI 백엔드(`GET /weather` → 기상청)로 통일한다.
/// (구조: Flutter → FastAPI → WeatherService → KMA)
/// 백엔드/기상청에서 데이터를 못 받아도 앱은 크래시하지 않고 명시적 fallback으로 표시한다.
class WeatherService {
  final String _baseUrl =
      dotenv.env['BACKEND_URL'] ?? "http://192.168.0.40:8000";

  /// 현재 날씨 조회 (백엔드 `GET /weather` → 기상청 단기예보)
  Future<WeatherInfo> getWeather() async {
    try {
      final uri = Uri.parse('$_baseUrl/weather');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return fallbackWeather('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final current =
          data['current'] is Map ? data['current'] : <String, dynamic>{};
      final today = data['today'] is Map ? data['today'] : <String, dynamic>{};
      final isFallback = data['is_fallback'] == true;
      final forecast = _parseForecast(data['forecast']);

      final locationName = _str(data['location_name']) ?? '부천시';
      return WeatherInfo(
        location: LocationInfo(
          city: locationName,
          fullAddress: locationName,
          latitude: _num(data['latitude']) ?? 0.0,
          longitude: _num(data['longitude']) ?? 0.0,
        ),
        condition: WeatherCondition.fromCode(_str(current['condition_code'])),
        temperature: _num(current['temperature']) ?? 0.0,
        feelsLike: _num(current['feels_like']),
        humidity: _int(current['humidity']),
        windSpeed: _num(current['wind_speed']),
        tempMin: _num(today['temp_min']),
        tempMax: _num(today['temp_max']),
        precipProbMax: _int(today['precip_prob_max']),
        forecast: forecast,
        isFallback: isFallback,
      );
    } catch (e) {
      print('Weather fetch failed: $e');
      return fallbackWeather(e.toString());
    }
  }

  /// 백엔드/기상청에서 데이터를 못 받을 때의 명시적 fallback.
  /// (가짜 기본값을 쓰지 않고 isFallback=true로 UI에 안내한다)
  WeatherInfo fallbackWeather(String reason) {
    print('Weather fallback: $reason');
    return const WeatherInfo(
      location: LocationInfo(
        city: '부천시',
        fullAddress: '경기도 부천시',
        latitude: 0.0,
        longitude: 0.0,
      ),
      condition: WeatherCondition.clear,
      temperature: 0.0,
      isFallback: true,
    );
  }

  /// 백엔드 `forecast` 배열 → 일별 예보 리스트 (오늘/내일/글피 ...)
  List<DailyForecastInfo> _parseForecast(dynamic raw) {
    final list = <DailyForecastInfo>[];
    if (raw is! List) return list;
    for (final item in raw) {
      if (item is! Map) continue;
      list.add(DailyForecastInfo(
        date: _str(item['date']) ?? '',
        label: _str(item['label']) ?? '',
        weekday: _str(item['weekday']) ?? '',
        tempMin: _num(item['temp_min']),
        tempMax: _num(item['temp_max']),
        conditionKorean: _str(item['condition_korean']) ?? '',
        conditionCode: _str(item['condition_code']) ?? 'clear',
        precipProbMax: _int(item['precip_prob_max']),
      ));
    }
    return list;
  }

  String? _str(dynamic v) => v?.toString();

  double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// 시즌 반환
  String getSeason() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    if (month >= 9 && month <= 11) return 'autumn';
    return 'winter';
  }
}
