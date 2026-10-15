"""위치 레지스트리.

현재는 부천시 원미구 심곡1동만 사용하지만, 향후 위치를 추가/변경하려면
아래 LOCATIONS에 항목만 등록하면 된다. (위치 변경 확장 포인트)

nx/ny는 기상청 동네예보 격자 좌표다. 위/경도는 향후 위경도 기반 조회
또는 클라이언트 위치 정보와 매칭을 위해 함께 보관한다.
"""
from dataclasses import dataclass
from typing import Dict


@dataclass(frozen=True)
class LocationConfig:
    id: str          # 유일 식별자 (캐시 키, API 쿼리 파라미터에도 사용)
    name: str        # 사람이 읽는 이름 (LLM 컨텍스트, UI 표시용)
    nx: int          # 기상청 격자 X
    ny: int          # 기상청 격자 Y
    latitude: float  # 위도 (참고/미래 위경도 조회용)
    longitude: float # 경도 (참고/미래 위경도 조회용)


# ---------------------------------------------------------------------------
# 위치 목록: 여기에 새 지역을 추가하면 즉시 사용 가능하다.
# ---------------------------------------------------------------------------
LOCATIONS: Dict[str, "LocationConfig"] = {
    "bucheon-simgok1": LocationConfig(
        id="bucheon-simgok1",
        name="부천시 원미구 심곡1동",
        nx=56,
        ny=125,
        latitude=37.5089,
        longitude=126.7746,
    ),
}

DEFAULT_LOCATION_ID = "bucheon-simgok1"


def get_location(location_id: str) -> "LocationConfig":
    """[location_id]에 해당하는 위치를 반환.

    알 수 없는 id가 들어오면 기본 위치로 안전하게 대체한다
    (존재하지 않는 위치로 KMA를 호출해 500이 나가는 걸 방지).
    """
    loc = LOCATIONS.get(location_id)
    if loc is None:
        return LOCATIONS[DEFAULT_LOCATION_ID]
    return loc
