import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// 캐릭터 의상(아웃핏) - 특정 캐릭터가 특정 상황에 입는 옷 조합
class CharacterOutfit {
  final String name;
  final String season;
  final String condition;
  final String basePath;
  Map<String, dynamic>? partsData;

  CharacterOutfit({
    required this.name,
    required this.season,
    required this.condition,
    required this.basePath,
    this.partsData,
  });

  /// 디렉토리 이름에서 season + condition 자동 파싱
  /// naming convention: {season}_{condition}_{style}
  factory CharacterOutfit.fromDirectory(String characterId, String dirName) {
    String season = 'summer';
    String condition = 'clear';

    if (dirName.contains('spring')) season = 'spring';
    else if (dirName.contains('summer')) season = 'summer';
    else if (dirName.contains('autumn')) season = 'autumn';
    else if (dirName.contains('winter')) season = 'winter';

    if (dirName.contains('rain')) condition = 'rain';
    else if (dirName.contains('snow')) condition = 'snow';
    else if (dirName.contains('cloudy') || dirName.contains('cloud'))
      condition = 'cloudy';

    return CharacterOutfit(
      name: dirName,
      season: season,
      condition: condition,
      basePath: 'assets/characters/$characterId/$dirName',
    );
  }

  /// parts_info.json 로드
  Future<bool> loadPartsData() async {
    if (partsData != null) return true;
    try {
      final jsonStr = await rootBundle.loadString('$basePath/parts_info.json');
      partsData = json.decode(jsonStr);
      return true;
    } catch (e) {
      print('Parts data load failed: $basePath - $e');
      return false;
    }
  }

  bool get isLoaded => partsData != null;

  double get canvasWidth {
    try {
      final firstPart = partsData!.values.first;
      if (firstPart is Map) {
        final cw = firstPart['canvas_width'];
        if (cw is num) return cw.toDouble();
      }
    } catch (_) {}
    return 1024.0;
  }

  double get canvasHeight {
    try {
      final firstPart = partsData!.values.first;
      if (firstPart is Map) {
        final ch = firstPart['canvas_height'];
        if (ch is num) return ch.toDouble();
      }
    } catch (_) {}
    return 1024.0;
  }
}

/// 캐릭터 프로필 - 여러 의상을 가진 캐릭터
class CharacterProfile {
  final String id;
  final String name;
  final String emoji;
  final List<CharacterOutfit> outfits;

  CharacterProfile({
    required this.id,
    required this.name,
    required this.emoji,
    required this.outfits,
  });

  /// 날씨에 맞는 의상 반환
  /// 우선순위: (계절+날씨) > 계절 > 날씨 > 첫 의상
  CharacterOutfit getOutfitFor(String season, String condition) {
    if (outfits.isEmpty) throw Exception('Character "$id" has no outfits');

    for (final o in outfits) {
      if (o.season == season && o.condition == condition) return o;
    }
    for (final o in outfits) {
      if (o.season == season) return o;
    }
    for (final o in outfits) {
      if (o.condition == condition) return o;
    }
    return outfits.first;
  }

  CharacterOutfit get defaultOutfit => outfits.first;
}