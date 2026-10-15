"""날씨 조회의 단일 진입점 (Orchestrator).

Flow: 캐시 확인 → 미스 시 프로바이더(KMA) 호출 → 성공 시 캐시 저장
       실패 시 명시적 fallback 반환 (앱 전체가 실패하지 않도록)

위치/캐시/프로바이더는 모두 주입되므로,
- 다른 외부 API → KmaWeatherProvider 대신 다른 프로바이더 주입
- Redis 캐시    → WeatherCache 구현체 주입
- 위치 변경     → locations.py / get_weather() 인자
를 각각 독립적으로 교체할 수 있다.
"""
import logging
import os
from typing import Optional

from .cache import InMemoryWeatherCache, WeatherCache
from .kma_provider import KmaWeatherProvider
from .locations import DEFAULT_LOCATION_ID, get_location
from .models import WeatherData

logger = logging.getLogger(__name__)


class WeatherService:
    def __init__(self, provider, cache: WeatherCache, default_location_id: str):
        self._provider = provider
        self._cache = cache
        self._default_location_id = default_location_id

    def get_weather(self, location_id: Optional[str] = None) -> WeatherData:
        """[location_id]의 현재 날씨를 반환 (캐싱 + 실패 시 fallback)."""
        location_id = location_id or self._default_location_id
        location = get_location(location_id)

        cached = self._cache.get(location_id)
        if cached is not None:
            logger.info(f"🌤️  날씨 캐시 HIT: {location.name}")
            return cached

        try:
            data = self._provider.fetch(location)
            self._cache.set(location_id, data)
            logger.info(
                f"🌤️  날씨 조회 OK(KMA): {location.name} "
                f"{data.current.temperature:.1f}℃ {data.current.condition_korean} "
                f"(오늘 {data.today.temp_min}~{data.today.temp_max}℃)"
            )
            return data
        except Exception as e:
            logger.error(f"⚠️  KMA 날씨 조회 실패 → fallback 반환: {e}")
            return WeatherData.fallback(location)

    def get_weather_context(self, location_id: Optional[str] = None) -> str:
        """LLM에 주입할 한국어 Weather Context 문자열."""
        return self.get_weather(location_id).to_weather_context()


# ---------------------------------------------------------------------------
# 싱글톤 (환경변수 기반). main.py가 import 후 호출한다.
# ---------------------------------------------------------------------------
_service: Optional[WeatherService] = None


def _build_service() -> WeatherService:
    api_key = os.getenv("KMA_API_KEY", "")
    ttl = int(os.getenv("WEATHER_CACHE_TTL", "600"))
    default_location_id = os.getenv("WEATHER_LOCATION", DEFAULT_LOCATION_ID)
    provider = KmaWeatherProvider(api_key=api_key)
    cache = InMemoryWeatherCache(ttl_seconds=ttl)
    return WeatherService(provider=provider, cache=cache, default_location_id=default_location_id)


def get_weather_service() -> WeatherService:
    global _service
    if _service is None:
        _service = _build_service()
    return _service
