"""날씨 캐시 추상화.

Redis 등은 당장 도입하지 않고, 프로세스 메모리 기반 TTL 캐시로 시작한다.
향후 Redis로 갈아끼우려면 아래 WeatherCache Protocol을 구현하는 클래스
(예: RedisWeatherCache)를 추가하고 WeatherService 생성 시 주입하면 된다.
(WeatherService 본문은 변경 불필요)
"""
import datetime
import threading
from typing import Any, Optional, Protocol, runtime_checkable


@runtime_checkable
class WeatherCache(Protocol):
    """캐시 인터페이스. get/set 두 메서드만 지키면 어떤 구현도 대체 가능."""

    def get(self, key: str) -> Optional[Any]:
        ...

    def set(self, key: str, value: Any) -> None:
        ...


class InMemoryWeatherCache:
    """프로세스 메모리 기반 TTL 캐시 (외부 의존성 없음, 스레드 안전)."""

    def __init__(self, ttl_seconds: int = 600):
        self._ttl = ttl_seconds
        self._store: dict = {}
        self._lock = threading.Lock()

    def _expired(self, stored_at: datetime.datetime) -> bool:
        return (datetime.datetime.now() - stored_at).total_seconds() >= self._ttl

    def get(self, key: str) -> Optional[Any]:
        with self._lock:
            entry = self._store.get(key)
            if entry is None:
                return None
            value, stored_at = entry
            if self._expired(stored_at):
                del self._store[key]
                return None
            return value

    def set(self, key: str, value: Any) -> None:
        with self._lock:
            self._store[key] = (value, datetime.datetime.now())

    def clear(self) -> None:
        with self._lock:
            self._store.clear()
