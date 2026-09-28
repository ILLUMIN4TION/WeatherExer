import 'package:flutter/material.dart';
import '../models/character_profile.dart';

/// 캐릭터 관리 서비스
/// - 캐릭터 레지스트리 / 현재 의상 상태 관리
/// - 날씨 기반 의상 자동 전환
class CharacterService extends ChangeNotifier {
  final List<CharacterProfile> _characters;
  int _currentIndex = 0;
  CharacterOutfit? _currentOutfit;
  bool _isReady = false;
  String _lastSeason = '';
  String _lastCondition = '';

  CharacterService() : _characters = _buildCharacterRegistry() {
    _currentOutfit = _characters[0].defaultOutfit;
  }

  // === Getter ===
  CharacterProfile get currentCharacter => _characters[_currentIndex];
  CharacterOutfit get currentOutfit => _currentOutfit!;
  int get currentIndex => _currentIndex;
  int get characterCount => _characters.length;
  List<CharacterProfile> get characters => _characters;
  bool get isReady => _isReady;

  // === 초기화 (앱 시작 시 호출) ===
  Future<void> initialize(String season, String condition) async {
    _lastSeason = season;
    _lastCondition = condition;

    final outfit = currentCharacter.getOutfitFor(season, condition);
    if (await outfit.loadPartsData()) {
      _currentOutfit = outfit;
      _isReady = true;
    } else {
      final fallback = currentCharacter.outfits.first;
      if (await fallback.loadPartsData()) {
        _currentOutfit = fallback;
        _isReady = true;
      }
    }
    notifyListeners();
  }

  // === 날씨 기반 의상 전환 ===
  Future<void> updateOutfitForWeather(String season, String condition) async {
    if (season == _lastSeason && condition == _lastCondition) return;
    _lastSeason = season;
    _lastCondition = condition;

    final outfit = currentCharacter.getOutfitFor(season, condition);
    if (await outfit.loadPartsData()) {
      _currentOutfit = outfit;
      _isReady = true;
      notifyListeners();
    }
  }

  // === 캐릭터 전환 ===
  Future<void> nextCharacter() async {
    if (_characters.length <= 1) return;
    _currentIndex = (_currentIndex + 1) % _characters.length;
    _isReady = false;
    notifyListeners();
    await _loadOutfitForCurrent();
  }

  Future<void> selectCharacter(int index) async {
    if (index < 0 || index >= _characters.length || index == _currentIndex)
      return;
    _currentIndex = index;
    _isReady = false;
    notifyListeners();
    await _loadOutfitForCurrent();
  }

  Future<void> _loadOutfitForCurrent() async {
    final outfit =
        currentCharacter.getOutfitFor(_lastSeason, _lastCondition);
    if (await outfit.loadPartsData()) {
      _currentOutfit = outfit;
      _isReady = true;
      notifyListeners();
    }
  }

  // === 캐릭터 레지스트리 ===
  // 새 캐릭터 추가 시:
  // 1. assets/characters/{id}/에 asset 디렉토리 생성
  // 2. pubspec.yaml에 asset 경로 추가
  // 3. 아래에 CharacterProfile 등록
  static List<CharacterProfile> _buildCharacterRegistry() {
    return [
      CharacterProfile(
        id: 'huge_breasts',
        name: '나희다',
        emoji: '🌸',
        outfits: [
          CharacterOutfit.fromDirectory('huge_breasts', 'summer_clear_twintail'),
          // 예:
          // CharacterOutfit.fromDirectory('huge_breasts', 'winter_snow_coat'),
          // CharacterOutfit.fromDirectory('huge_breasts', 'autumn_rain_umbrella'),
        ],
      ),
      // CharacterProfile(
      //   id: 'character_b',
      //   name: '새 캐릭터',
      //   emoji: '🌙',
      //   outfits: [
      //     CharacterOutfit.fromDirectory('character_b', 'summer_clear_default'),
      //   ],
      // ),
    ];
  }
}