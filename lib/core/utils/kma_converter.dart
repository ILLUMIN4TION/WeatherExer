import 'dart:math';

/// 기상청 단기예보(동네예보) 격자 좌표 변환기
/// (위도, 경도) <-> (X, Y)
class KmaConverter {
  // 기상청에서 제공하는 변환 상수들 (람베르트 원추 등각 투영법)
  static const double RE = 6371.00877; // 지구 반경(km)
  static const double GRID = 5.0;      // 격자 간격(km)
  static const double SLAT1 = 30.0;    // 투영 위도1(degree)
  static const double SLAT2 = 60.0;    // 투영 위도2(degree)
  static const double OLON = 126.0;    // 기준점 경도(degree)
  static const double OLAT = 38.0;     // 기준점 위도(degree)
  static const double XO = 43;         // 기준점 X좌표(GRID)
  static const double YO = 136;        // 기준점 Y좌표(GRID)

  /// 위경도를 기상청 X, Y 격자 좌표로 변환하는 함수
  static Map<String, int> latLonToGrid(double lat, double lon) {
    double degrad = pi / 180.0;

    double re = RE / GRID;
    double slat1 = SLAT1 * degrad;
    double slat2 = SLAT2 * degrad;
    double olon = OLON * degrad;
    double olat = OLAT * degrad;

    double sn = tan(pi * 0.25 + slat2 * 0.5) / tan(pi * 0.25 + slat1 * 0.5);
    sn = log(cos(slat1) / cos(slat2)) / log(sn);
    double sf = tan(pi * 0.25 + slat1 * 0.5);
    sf = pow(sf, sn) * cos(slat1) / sn;
    double ro = tan(pi * 0.25 + olat * 0.5);
    ro = re * sf / pow(ro, sn);

    double ra = tan(pi * 0.25 + (lat) * 0.5);
    ra = re * sf / pow(ra, sn);
    double theta = lon * degrad - olon;
    if (theta > pi) theta -= 2.0 * pi;
    if (theta < -pi) theta += 2.0 * pi;
    theta *= sn;

    int x = (ra * sin(theta) + XO + 0.5).floor();
    int y = (ro - ra * cos(theta) + YO + 0.5).floor();

    return {'x': x, 'y': y};
  }
}