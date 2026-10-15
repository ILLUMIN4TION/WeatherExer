"""규격화된 날씨 데이터 모델.

KMA 원본 응답(수십 종의 category, 시간별)을 이 구조로 정규화한다.
- to_dict():            API(JSON) 응답용 (클라이언트 /weather)
- to_weather_context(): LLM에 주입할 한국어 컨텍스트 블록
- fallback():           KMA 실패 시 "가짜가 아닌" 명시적 대체 데이터
"""
import datetime
from dataclasses import dataclass, field
from typing import List, Optional


def _temp_str(v) -> str:
    """기온 표시(TTS 친화): 정수값은 소수점 없이 (22.0 → '22'), 소수값은 유지 (22.5 → '22.5').

    to_weather_context() 텍스트 표시에만 사용된다.
    내부 저장(float)이나 to_dict() JSON 구조는 변경하지 않는다.
    """
    if v is None:
        return "?"
    v = float(v)
    return str(int(v)) if v == int(v) else f"{v:g}"


@dataclass
class CurrentWeather:
    """현재(가장 가까운 예보 시점) 상태."""
    temperature: float
    feels_like: Optional[float]
    condition_korean: str        # "맑음", "비", ... (상세)
    condition_code: str          # "clear"|"rain"|"snow"|"cloudy" (UI 4종)
    humidity: Optional[int]
    wind_speed: Optional[float]  # m/s
    wind_direction: Optional[int]  # degree
    precipitation_korean: str    # "강수 없음", "비", ...


@dataclass
class DailySummary:
    """오늘 일별 요약."""
    temp_min: Optional[float]
    temp_max: Optional[float]
    precip_prob_max: Optional[int]  # %


@dataclass
class DailyForecast:
    """单日(오늘/내일/모레/글피 등) 일별 예보.

    프로바이더(KMA)가 단기예보 그리드의 fcstDate별 요약으로 만든다.
    """
    date: str                  # "2026-10-01"
    label: str                 # "오늘" | "내일" | "모레" | "글피" | "10월 4일" (그 뒤부터)
    weekday: str               # "월"~"일"
    temp_min: Optional[float]
    temp_max: Optional[float]
    condition_korean: str      # "맑음" | "비" | "눈" ...
    condition_code: str        # "clear"|"rain"|"snow"|"cloudy" (UI 4종)
    precip_prob_max: Optional[int]  # %


@dataclass
class WeatherData:
    location_id: str
    location_name: str
    latitude: float
    longitude: float
    source: str            # "kma" | "fallback"
    is_fallback: bool      # True면 실제 데이터 아님 (UI/LLM이 구분)
    observed_at: str       # "2026-09-30 02:00"
    sky_korean: str        # "맑음"|"구름조금"|"구름많음"|"흐림"
    current: "CurrentWeather"
    today: "DailySummary"
    forecast: List["DailyForecast"] = field(default_factory=list)  # 오늘/내일/글피 일별 예보

    # ------------------------------------------------------------------
    # KMA 실패 시 사용할 명시적 fallback (가짜 수치를 만들지 않음)
    # ------------------------------------------------------------------
    @classmethod
    def fallback(cls, location) -> "WeatherData":
        now = datetime.datetime.now()
        return cls(
            location_id=location.id,
            location_name=location.name,
            latitude=location.latitude,
            longitude=location.longitude,
            source="fallback",
            is_fallback=True,
            observed_at=now.strftime("%Y-%m-%d %H:%M"),
            sky_korean="미상",
            current=CurrentWeather(
                temperature=0.0,
                feels_like=None,
                condition_korean="알 수 없음",
                condition_code="unknown",
                humidity=None,
                wind_speed=None,
                wind_direction=None,
                precipitation_korean="미상",
            ),
            today=DailySummary(temp_min=None, temp_max=None, precip_prob_max=None),
        )

    # ------------------------------------------------------------------
    def to_dict(self) -> dict:
        """클라이언트 /weather 엔드포인트용 JSON 응답."""
        return {
            "location_id": self.location_id,
            "location_name": self.location_name,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "source": self.source,
            "is_fallback": self.is_fallback,
            "observed_at": self.observed_at,
            "current": {
                "temperature": self.current.temperature,
                "feels_like": self.current.feels_like,
                "condition_korean": self.current.condition_korean,
                "condition_code": self.current.condition_code,
                "humidity": self.current.humidity,
                "wind_speed": self.current.wind_speed,
                "wind_direction": self.current.wind_direction,
                "precipitation_korean": self.current.precipitation_korean,
            },
            "today": {
                "temp_min": self.today.temp_min,
                "temp_max": self.today.temp_max,
                "precip_prob_max": self.today.precip_prob_max,
            },
            "forecast": [
                {
                    "date": f.date,
                    "label": f.label,
                    "weekday": f.weekday,
                    "temp_min": f.temp_min,
                    "temp_max": f.temp_max,
                    "condition_korean": f.condition_korean,
                    "condition_code": f.condition_code,
                    "precip_prob_max": f.precip_prob_max,
                }
                for f in self.forecast
            ],
        }

    # ------------------------------------------------------------------
    def to_weather_context(self) -> str:
        """LLM 프롬프트에 주입할 'Weather Context' (한국어, 실시간 수치가 포함됨)."""
        if self.is_fallback:
            return (
                "[날씨 정보] 지금 기상청 데이터를 불러오지 못했습니다. "
                "날씨를 정확히 모른다는 점을 인정하고, 숫자를 추측하거나 지어내지 말고 "
                "\"오늘 날씨는 지금 바로 확인하기가 어렵네요~\" 처럼 자연스럽게 말하세요."
            )
        c = self.current
        lines = [
            "[현재 날씨 정보 - 기상청 단기예보, 실시간 데이터]",
            f"위치: {self.location_name}",
            f"기준 시각: {self.observed_at}",
        ]
        temp_line = f"현재 기온: {_temp_str(c.temperature)}도"
        if c.feels_like is not None:
            temp_line += f" (체감 {_temp_str(c.feels_like)}도)"
        lines.append(temp_line)
        lines.append(f"하늘: {self.sky_korean} / 강수: {c.precipitation_korean}")
        if self.today.temp_min is not None and self.today.temp_max is not None:
            lines.append(
                f"오늘 기온 범위: {_temp_str(self.today.temp_min)}도 ~ {_temp_str(self.today.temp_max)}도"
            )
        if self.today.precip_prob_max is not None:
            lines.append(f"오늘 최대 강수확률: {self.today.precip_prob_max}퍼센트")
        if c.humidity is not None:
            lines.append(f"습도: {c.humidity}퍼센트")
        if c.wind_speed is not None:
            lines.append(f"풍속: {c.wind_speed:.1f}m/s")
        # 일별 예보(내일/글피/...) - "내일 날씨" 같은 질문 답변용
        for f in self.forecast:
            if f.label == "오늘":
                continue  # 오늘은 이미 위에 포함
            if f.temp_min is None or f.temp_max is None:
                continue
            if f.label in ("내일", "모레", "글피"):
                head = f"{f.label}({int(f.date[5:7])}월 {int(f.date[8:10])}일 {f.weekday})"
            else:
                head = f"{f.label}({f.weekday})"
            parts = [
                f"{head} 예보: {f.condition_korean}",
                f"{_temp_str(f.temp_min)}도 ~ {_temp_str(f.temp_max)}도",
            ]
            if f.precip_prob_max is not None:
                parts.append(f"최대 강수확률 {f.precip_prob_max}퍼센트")
            lines.append(", ".join(parts))
        lines.append(
            "※ 위 수치는 실제 기상청 데이터입니다. 날씨·기온·강수·바람 관련 질문에는 "
            "이 정보를 최우선으로 사용하세요. '내일'·'모레'·'글피' 질문은 위의 "
            "일별 예보로 답하세요."
        )
        return "\n".join(lines)
