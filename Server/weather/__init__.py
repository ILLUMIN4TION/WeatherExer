"""날씨(기상청) 도메인 패키지.

KMA 호출·파싱·규격화·캐싱을 main.py에서 분리해 위치 변경, 캐싱 교체,
다른 외부 API 연동, 개인화 기능으로 확장하기 쉽게 만든다.

공개 API:
    from weather import get_weather_service, WeatherData, LocationConfig, LOCATIONS
"""
from .models import WeatherData, CurrentWeather, DailySummary
from .service import WeatherService, get_weather_service
from .locations import LocationConfig, LOCATIONS, DEFAULT_LOCATION_ID, get_location
from .cache import WeatherCache, InMemoryWeatherCache
from .kma_provider import KmaWeatherProvider

__all__ = [
    "WeatherData",
    "CurrentWeather",
    "DailySummary",
    "WeatherService",
    "get_weather_service",
    "LocationConfig",
    "LOCATIONS",
    "DEFAULT_LOCATION_ID",
    "get_location",
    "WeatherCache",
    "InMemoryWeatherCache",
    "KmaWeatherProvider",
]
