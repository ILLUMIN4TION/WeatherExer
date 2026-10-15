"""기상청 단기예보(동네예보) 프로바이더.

KMA API 호출, 원본 응답 파싱, WeatherData 정규화 로직을 모두 여기서만 가진다.
(main.py에 넣지 않는 것이 분리 원칙)

- 다른 외부 API(예: open-meteo, 다른 공공 API)로 확장하려면
  이 파일을 다른 프로바이더로 교체하거나 WeatherService에서 주입만 바꾸면 된다.
"""
import datetime
import logging
from collections import defaultdict
from typing import List, Optional, Tuple

import httpx

from .locations import LocationConfig
from .models import CurrentWeather, DailyForecast, DailySummary, WeatherData

logger = logging.getLogger(__name__)

# 기상청 동네예보 엔드포인트 (검증: resultCode=00 NORMAL_SERVICE)
KMA_URL = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst"

# 단기예보 발표 시각 (3시간 간격: 02 05 08 11 14 17 20 23)
# ⚠️ 기존 클라이언트는 (hour ~/ 3) * 3 으로 00/03/06/09...를 만들어 API가 실패했다.
#    단기예보는 02/05/08...이어야 정상 동작한다. (요구사항 7)
_BASE_HOURS = (2, 5, 8, 11, 14, 17, 20, 23)

_SKY_KR = {1: "맑음", 2: "구름조금", 3: "구름많음", 4: "흐림"}
_PTY_KR = {0: "강수 없음", 1: "비", 2: "비/소나기", 3: "눈/진눈깨비", 4: "비와 눈"}
_WEEKDAYS_KR = ("월", "화", "수", "목", "금", "토", "일")


def _to_float(v) -> Optional[float]:
    try:
        if v is None or v == "":
            return None
        return float(v)
    except (TypeError, ValueError):
        return None


def _to_int(v) -> Optional[int]:
    f = _to_float(v)
    return None if f is None else int(f)


class KmaWeatherProvider:
    """기상청 단기예보 API를 호출해 WeatherData로 정규화한다."""

    def __init__(self, api_key: str, timeout: float = 15.0):
        self._api_key = api_key
        self._timeout = timeout

    # ------------------------------------------------------------------
    # 공개 API
    # ------------------------------------------------------------------
    def fetch(self, location: LocationConfig, now: Optional[datetime.datetime] = None) -> WeatherData:
        """[location]의 현재/오늘 날씨를 KMA에서 조회해 WeatherData로 반환.

        실패하면 예외를 던진다 (캐싱·fallback 처리는 WeatherService가 담당).
        """
        now = now or datetime.datetime.now()
        if not self._api_key:
            raise RuntimeError("KMA_API_KEY가 설정되어 있지 않습니다.")

        base_date, base_time = self._latest_base_time(now)
        params = {
            "serviceKey": self._api_key,
            "numOfRows": 1000,   # 24시간 × 다수 category → 한 페이지에 전부 받아야 일별 요약이 정확
            "pageNo": 1,
            "dataType": "json",
            "base_date": base_date,
            "base_time": base_time,
            "nx": location.nx,
            "ny": location.ny,
        }
        resp = httpx.get(KMA_URL, params=params, timeout=self._timeout)
        resp.raise_for_status()
        raw = resp.json()

        header = raw.get("response", {}).get("header", {})
        if str(header.get("resultCode")) not in ("00", "200"):
            raise RuntimeError(f"KMA API 오류: {header.get('resultCode')} {header.get('resultMsg')}")

        return self._parse(raw, location, now)

    # ------------------------------------------------------------------
    # 내부
    # ------------------------------------------------------------------
    def _latest_base_time(self, now: datetime.datetime) -> Tuple[str, str]:
        """현재 시각 기준 가장 최근 발표된 (base_date, base_time)을 반환.

        02~05시 사이면 어제 23시 발표분을 사용한다.
        """
        for h in reversed(_BASE_HOURS):
            t = now.replace(hour=h, minute=0, second=0, microsecond=0)
            if t <= now:
                return t.date().strftime("%Y%m%d"), f"{h:02d}00"
        yesterday = now - datetime.timedelta(days=1)
        return yesterday.date().strftime("%Y%m%d"), "2300"

    def _map_condition(self, pty: str, sky: str) -> Tuple[str, str]:
        """(PTY, SKY) → (상세 한국어, UI용 4종 코드).

        PTY: 0=없음 1=비 2=비/소나기 3=눈 4=비와눈
        SKY: 1=맑음 2=구름조금 3=구름많음 4=흐림
        """
        pty_i = int(pty) if pty and pty.isdigit() else 0
        sky_i = int(sky) if sky and sky.isdigit() else 1
        sky_kr = _SKY_KR.get(sky_i, "맑음")

        if pty_i == 3:
            return ("눈", "snow")
        if pty_i in (1, 2, 4):
            return ("비", "rain")
        # 강수 없음 → 하늘 상태로 구분
        if sky_i in (1, 2):
            return (sky_kr, "clear")
        return (sky_kr, "cloudy")

    def _parse(self, raw: dict, location: LocationConfig, now: datetime.datetime) -> WeatherData:
        body = raw["response"]["body"]
        items = body.get("items", [])
        if isinstance(items, dict):
            items = items.get("item", [])

        # (fcstDate, fcstTime) → {category: fcstValue}
        grid = defaultdict(dict)
        for it in items:
            if not isinstance(it, dict):
                continue
            key = (it.get("fcstDate"), it.get("fcstTime"))
            grid[key][it.get("category")] = it.get("fcstValue")
        if not grid:
            raise RuntimeError("KMA 응답에 예보 항목(items)이 없습니다.")

        def _dt(d: str, t: str) -> datetime.datetime:
            return datetime.datetime(
                int(d[:4]), int(d[4:6]), int(d[6:8]), int(t[:2]), int(t[2:4])
            )

        # 현재 시점에 가장 가까운 예보 시점을 "현재"로 채택
        cur_key = min(grid.keys(), key=lambda k: abs((_dt(*k) - now).total_seconds()))
        cur = grid[cur_key]

        temp = _to_float(cur.get("TMP")) or 0.0
        feels = _to_float(cur.get("TEF"))
        humidity = _to_int(cur.get("REH"))
        wind_speed = _to_float(cur.get("WSD"))
        wind_dir = _to_int(cur.get("VEC"))
        sky = str(cur.get("SKY", "1"))
        pty = str(cur.get("PTY", "0"))

        pty_i = int(pty) if pty and pty.isdigit() else 0
        sky_i = int(sky) if sky and sky.isdigit() else 1
        cond_kr, cond_code = self._map_condition(pty, sky)
        sky_kr = _SKY_KR.get(sky_i, "맑음")
        precip_kr = _PTY_KR.get(pty_i, "강수 없음")

        # 오늘 일별 요약 (fcstDate == today)
        today_str = now.strftime("%Y%m%d")
        today_cells = [v for (d, _t), v in grid.items() if d == today_str]
        temps = [x for x in (_to_float(v.get("TMP")) for v in today_cells) if x is not None]
        pops = [x for x in (_to_float(v.get("POP")) for v in today_cells) if x is not None]

        # 일별 예보(오늘/내일/모레/글피/...) - 응답의 각 fcstDate를 하루 단위로 요약
        # (단기예보 응답은 기준 시각 이후 여러 일을 포함하므로 최소 글피(오늘+3)까지 확보)
        by_date: dict = defaultdict(list)
        for (d, _t), v in grid.items():
            by_date[d].append(v)

        forecast: List[DailyForecast] = []
        now_date = now.date()
        for d in sorted(by_date):
            date_obj = datetime.date(int(d[:4]), int(d[4:6]), int(d[6:8]))
            diff = (date_obj - now_date).days
            if diff == 0:
                label = "오늘"
            elif diff == 1:
                label = "내일"
            elif diff == 2:
                label = "모레"
            elif diff == 3:
                label = "글피"
            else:
                label = f"{date_obj.month}월 {date_obj.day}일"
            cells = by_date[d]
            dtemps = [x for x in (_to_float(v.get("TMP")) for v in cells) if x is not None]
            dpops = [x for x in (_to_float(v.get("POP")) for v in cells) if x is not None]
            # 당일 대표 상태: 강수확률(POP)이 가장 큰 시점 채택 → 비 예보가 있으면 "비"로 노출
            best = max(cells, key=lambda v: float(v.get("POP") or 0))
            cond_kr, cond_code = self._map_condition(
                str(best.get("PTY", "0")), str(best.get("SKY", "1"))
            )
            forecast.append(
                DailyForecast(
                    date=f"{d[:4]}-{d[4:6]}-{d[6:8]}",
                    label=label,
                    weekday=_WEEKDAYS_KR[date_obj.weekday()],
                    temp_min=min(dtemps) if dtemps else None,
                    temp_max=max(dtemps) if dtemps else None,
                    precip_prob_max=int(max(dpops)) if dpops else None,
                    condition_korean=cond_kr,
                    condition_code=cond_code,
                )
            )

        return WeatherData(
            location_id=location.id,
            location_name=location.name,
            latitude=location.latitude,
            longitude=location.longitude,
            source="kma",
            is_fallback=False,
            observed_at=f"{cur_key[0][:4]}-{cur_key[0][4:6]}-{cur_key[0][6:8]} {cur_key[1][:2]}:{cur_key[1][2:]}",
            sky_korean=sky_kr,
            current=CurrentWeather(
                temperature=temp,
                feels_like=feels,
                condition_korean=cond_kr,
                condition_code=cond_code,
                humidity=humidity,
                wind_speed=wind_speed,
                wind_direction=wind_dir,
                precipitation_korean=precip_kr,
            ),
            today=DailySummary(
                temp_min=min(temps) if temps else None,
                temp_max=max(temps) if temps else None,
                precip_prob_max=int(max(pops)) if pops else None,
            ),
            forecast=forecast,
        )
