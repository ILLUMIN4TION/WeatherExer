/// 캐릭터 파트 정보 모델
class CharacterPartInfo {
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final double canvasWidth;
  final double canvasHeight;

  CharacterPartInfo({
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  /// JSON에서 파싱
  factory CharacterPartInfo.fromJson(Map<String, dynamic> json, {
    required double canvasWidth,
    required double canvasHeight,
  }) {
    return CharacterPartInfo(
      name: json['name'] as String? ?? 'unknown',
      x: (json['x'] is num) ? (json['x'] as num).toDouble() : 0.0,
      y: (json['y'] is num) ? (json['y'] as num).toDouble() : 0.0,
      width: (json['width'] is num) ? (json['width'] as num).toDouble() : 0.0,
      height: (json['height'] is num) ? (json['height'] as num).toDouble() : 0.0,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
    );
  }

  /// 파일명에서 파트 이름 추출 (예: "hair_front.PNG" → "hair_front")
  static String extractNameFromFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'\.[^.]*$'), '');
  }
}

/// 캐릭터 설정 모델
class CharacterConfig {
  final String name;
  final String basePath;
  final CharacterPartInfo? firstPartInfo;

  CharacterConfig({
    required this.name,
    required this.basePath,
    this.firstPartInfo,
  });

  /// JSON 파일에서 캐릭터 설정 로드
  factory CharacterConfig.fromJsonFile(Map<String, dynamic> jsonData) {
    final canvasWidth = (jsonData['canvas_width'] is num)
        ? (jsonData['canvas_width'] as num).toDouble()
        : 832.0;
    final canvasHeight = (jsonData['canvas_height'] is num)
        ? (jsonData['canvas_height'] as num).toDouble()
        : 1216.0;

    final parts = <CharacterPartInfo>[];
    jsonData.forEach((key, value) {
      if (key != 'canvas_width' && key != 'canvas_height') {
        parts.add(CharacterPartInfo.fromJson(
          value as Map<String, dynamic>,
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
        ));
      }
    });

    return CharacterConfig(
      name: jsonData['name'] as String? ?? 'character',
      basePath: '',
      firstPartInfo: parts.isNotEmpty ? parts.first : null,
    );
  }
}