import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:weathexer/models/character_profile.dart';
import 'package:weathexer/services/character_service.dart';
import 'package:weathexer/services/weather_service.dart';
import 'package:weathexer/viewmodels/chat_view_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _idleController;
  final TextEditingController _textController = TextEditingController();
  final WeatherService _weatherService = WeatherService();

  WeatherInfo? _weather;
  String _currentSeason = 'summer';
  String _currentWeather = 'clear';
  final String _currentAngle = 'mid';
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final weather = await _weatherService.getWeather();
      if (!mounted) return;
      final season = _weatherService.getSeason();
      setState(() {
        _weather = weather;
        _currentSeason = season;
        _currentWeather = weather.condition.code;
        _isInitializing = false;
      });
      await context.read<CharacterService>().initialize(
          season, weather.condition.code);
    } catch (_) {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Offset _getBreathingOffset(String partName, double progress) {
    final double t = progress * 2 * math.pi;
    if (partName.contains('bottom') || partName.contains('leg') || partName.contains('foot')) return Offset.zero;
    if (partName.contains('hand') || partName.contains('arm')) return Offset(0, math.sin(t - 0.5) * 3);
    return Offset(0, math.sin(t) * 4.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/backgrounds/$_currentSeason/${_currentWeather}_$_currentAngle.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Color(0xFF2C3E50),
              child:
                  Center(child: Text('🌤️', style: TextStyle(fontSize: 64))),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Consumer<CharacterService>(
              builder: (context, charService, child) {
                if (_isInitializing || !charService.isReady) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child:
                          CircularProgressIndicator(color: Colors.white54),
                    ),
                  );
                }
                return _buildCharacterLayer(charService.currentOutfit);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWeatherInfo(),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAiSpeechBubble(),
                      const SizedBox(width: 12),
                      _buildCharacterSwitchButton(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: _buildChatInputArea(),
          ),
        ],
      ),
    );
  }

  // --- 위젯 분리 (코드 가독성) ---

  Widget _buildCharacterLayer(CharacterOutfit outfit) {
    final partsData = outfit.partsData!;
    final canvasW = outfit.canvasWidth;
    final canvasH = outfit.canvasHeight;
    final basePath = outfit.basePath;

    return AnimatedBuilder(
      animation: _idleController,
      builder: (context, child) {
        return AspectRatio(
          aspectRatio: canvasW / canvasH,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              List<Widget> stackChildren = [];

              partsData.forEach((partName, info) {
                if (info is! Map) return;
                final x = (info['x'] as num).toDouble();
                final y = (info['y'] as num).toDouble();
                final partW = (info['width'] as num).toDouble();
                final partH = (info['height'] as num).toDouble();
                double angle = 0.0;
                Alignment alignment = Alignment.center;

                if (partName.contains('hair')) {
                  alignment = Alignment.topCenter;
                  angle =
                      math.sin(_idleController.value * 2 * math.pi * 1.5) *
                          0.03;
                }

                stackChildren.add(
                  Positioned(
                    left: w * (x / canvasW),
                    top: h * (y / canvasH),
                    width: w * (partW / canvasW),
                    height: h * (partH / canvasH),
                    child: Transform.translate(
                      offset:
                          _getBreathingOffset(partName, _idleController.value),
                      child: Transform.rotate(
                        angle: angle,
                        alignment: alignment,
                        child: Image.asset(
                          '$basePath/$partName.PNG',
                          fit: BoxFit.fill,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.red.withOpacity(0.1)),
                        ),
                      ),
                    ),
                  ),
                );
              });
              return Stack(fit: StackFit.expand, children: stackChildren);
            },
          ),
        );
      },
    );
  }

  // --- 현재(단기) 날씨 정보 (글래스모피즘 카드) ---
  // 캐릭터(하단 중앙)를 가리지 않도록 상단 전체 너비로 배치
  Widget _buildWeatherInfo() {
    const accent = Color(0xFF00E676);
    if (_weather == null) {
      return _glassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
      );
    }
    if (_weather!.isFallback) {
      return _glassCard(
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '기상청 데이터를 불러오지 못했어요\n현재 위치: ${_weather!.location.city}',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
              ),
            ),
          ],
        ),
      );
    }
    final w = _weather!;
    final upcoming = _upcomingForecasts(w);
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1행: 위치 + 현재기온 + 상태
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.location_on, color: accent, size: 18),
              const SizedBox(width: 5),
              Text(
                w.location.city,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              Text(
                '${w.temperature.toStringAsFixed(0)}°',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w300,
                    height: 1.0),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    w.conditionKorean,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                  if (w.feelsLike != null)
                    Text(
                      '체감 ${w.feelsLike!.toStringAsFixed(0)}°',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 10),
          // 2행: 단기 지표 (습도 / 풍속 / 강수확률 / 오늘 기온)
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _buildMetric(Icons.water_drop, _fmtHumidity(w.humidity)),
              _buildMetric(Icons.air, _fmtWind(w.windSpeed)),
              _buildMetric(Icons.opacity, _fmtPrecip(w.precipProbMax)),
              _buildMetric(Icons.thermostat, _fmtToday(w.tempMin, w.tempMax)),
            ],
          ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: Colors.white.withOpacity(0.15)),
            const SizedBox(height: 8),
            // 3행: 일별 예보 (내일 / 글피)
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final f in upcoming)
                  _buildMetric(Icons.event, _fmtForecast(f)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 글래스모피즘 공통 카드 (배경 블러 15 + 반투명)
  Widget _glassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding:
              padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.20), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMetric(IconData icon, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white54, size: 13),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  String _fmtHumidity(int? v) => v == null ? '' : '습도 $v%';
  String _fmtWind(double? v) => v == null ? '' : '풍속 ${v.toStringAsFixed(1)}';
  String _fmtPrecip(int? v) => v == null ? '' : '강수 $v%';
  String _fmtToday(double? min, double? max) =>
      (min == null || max == null)
          ? ''
          : '오늘 ${min.toStringAsFixed(0)}°~${max.toStringAsFixed(0)}°';

  /// 내일/글피 예보 (카드 3행용, "오늘"은 2행에 이미 표시됨)
  List<DailyForecastInfo> _upcomingForecasts(WeatherInfo w) => w.forecast
      .where((f) => f.label.isNotEmpty && f.label != '오늘')
      .take(2)
      .toList();

  String _fmtForecast(DailyForecastInfo f) {
    final parts = <String>[f.label];
    if (f.tempMin != null && f.tempMax != null) {
      parts.add(
          '${f.tempMin!.toStringAsFixed(0)}°~${f.tempMax!.toStringAsFixed(0)}°');
    }
    if (f.conditionKorean.isNotEmpty) parts.add(f.conditionKorean);
    return parts.join(' ');
  }

  // 🔥 ViewModel의 상태(aiText)를 구독하여 말풍선 표시
  Widget _buildAiSpeechBubble() {
    return Flexible(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                reverse: true,
                child: Consumer<ChatViewModel>(
                  builder: (context, viewModel, child) {
                    return Text(
                      viewModel.currentAiText,
                      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                      softWrap: true,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterSwitchButton() {
    return Consumer<CharacterService>(
      builder: (context, charService, child) {
        final character = charService.currentCharacter;
        return GestureDetector(
          onTap: charService.characterCount > 1
              ? () => charService.nextCharacter()
              : null,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.4),
              border: Border.all(
                  color: Colors.white.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(character.emoji, style: const TextStyle(fontSize: 24)),
                if (charService.characterCount > 1)
                  const Icon(Icons.swap_vert,
                      size: 10, color: Colors.white54),
              ],
            ),
          ),
        );
      },
    );
  }

  void _sendMessage(String message) {
    if (message.trim().isEmpty) return;
    context.read<ChatViewModel>().sendMessage(
          message,
          location: _weather?.location.city ?? '현재 위치',
          weather: (_weather != null && !_weather!.isFallback)
              ? _weather!.conditionKorean
              : '알 수 없음',
        );
  }

  // 하단 텍스트 입력창
  Widget _buildChatInputArea() {
    return Consumer<ChatViewModel>(
      builder: (context, viewModel, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      enabled: !viewModel.isLoading,
                      onSubmitted: (value) {
                        _sendMessage(value);
                        _textController.clear();
                      },
                      decoration: const InputDecoration(
                        hintText: "무엇이든 물어보세요...",
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: viewModel.isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: viewModel.isLoading
                        ? null
                        : () {
                            _sendMessage(_textController.text);
                            _textController.clear();
                            FocusScope.of(context).unfocus();
                          },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}