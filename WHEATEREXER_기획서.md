# WeatherExer 기획서

> **WeatherExer** — 실시간 기상청(KMA) 데이터를 기반으로 날씨·일상을 **한국어 음성**으로 대화하는 AI 캐릭터 챗봇.
>
> - 성격: **AI 음성 풀파이프라인 학습** 목적으로 구축된 풀스택 프로젝트
> - 스택: Flutter(클라이언트) → FastAPI(백엔드) → llama.cpp/Qwen(LLM) + GPT-SoVITS(TTS) + 기상청(날씨)
> - 문서 목적: GitHub / Notion용 프로젝트 기획 문서
>
> **목차**
> 1. [요구사항 정의서 (MoSCoW)](#1-요구사항-정의서)
> 2. [기획서 — 화면 설계 & 디자인 시스템](#2-기획서--화면-설계-디자인-시스템)
> 3. [IA (정보구조도)](#3-ia-정보구조도)
> 4. [기술스택](#4-기술스택)
> 5. [API 명세서](#5-api-명세서)
> 6. [개발과정 / 문제해결](#6-개발과정--문제해결)

---

## 1. 요구사항 정의서

### 1.1 제품 비전
날씨와 일상에 대해 **말하듯** 묻고, **목소리로** 대답하며, **날씨에 따라 표정과 옷이 바뀌는 캐릭터**와 함께하는 동반자(companion)형 음성 챗봇.

- **정확성**: 실제 기상청 데이터로 답함 (모델이 날림 숫자를 지어내지 않음)
- **몰입감**: 계절/날씨 기반 배경 + 캐릭터 의상, 문장별 자연스러운 한국어 음성
- **학습 목적**: Flutter → FastAPI → LLM → TTS → SSE의 **음성 AI 풀파이프라인**을 직접 구현·운영

### 1.2 사용자 (Persona)
- 한국어 사용자
- "지금 날씨 어때?", "출근 준비할까?" 같은 **날씨·일상** 대화가 필요한 사용자
- 텍스트보다 **음성으로** 주고받는 것을 선호

### 1.3 요구사항 (MoSCoW)

> **MoSCoW** = **M**ust(없으면 불가) / **S**hould(있어야 품질↑) / **C**ould(있으면 좋음) / **W**on't(이번 릴리스 제외)
> **상태** ✅=구현 · ⚠️=부분/예정 · ❌=미구현

#### MUST (MVP 성립 필수)
| ID | 요구사항 | 상태 |
|----|----------|------|
| M1 | **날씨 기반 음성 채팅** — 텍스트 입력 → LLM 한국어 답변 → 문장별 TTS 음성 재생 | ✅ |
| M2 | **실시간 기상청(KMA) 연동** — 현재/오늘 날씨를 실제 데이터로 조회 | ✅ |
| M3 | **날씨 컨텍스트 주입** — LLM 답변에 실측 수치 반영 (가짜 수치/추측 금지) | ✅ |
| M4 | **SSE 스트리밍** — 문장 단위로 `text`+`audio`를 실시간 전송 (첫 응답 지연↓) | ✅ |
| M5 | **홈 화면** — 날씨 배경 + 캐릭터 + 채팅 입력 | ✅ |
| M6 | **Fallback** — KMA/LLM/TTS 실패 시 가짜 데이터 없이 "확인 불가" 안내, 앱 크래시 없음 | ✅ |

#### SHOULD (MVP 품질·완결성)
| ID | 요구사항 | 상태 |
|----|----------|------|
| S1 | **날씨 반응형 캐릭터 의상** — (계절+날씨) 기반 자동 교체 | ✅ |
| S2 | **날씨 배경화면** — 계절/날씨/앵글 기반 | ✅ |
| S3 | **설정 화면** — 캐릭터 선택, 현재 의상 정보 | ✅ |
| S4 | **타이핑 애니메이션 ↔ 음성 동기화** — 재생되는 문장만큼 텍스트 표시 | ✅ |
| S5 | **오디오 큐 관리** — 문장별 WAV 큐, 재생 순서 보장, 임시파일 정리 | ✅ |

#### COULD (있으면 좋음)
| ID | 요구사항 | 상태 |
|----|----------|------|
| C1 | **실 GPS 위치 기반 날씨** (geolocator) | ⚠️ (권한 미설정, 기본값 사용) |
| C2 | **웹검색(DDGS) 반영** — 최신 정보(기상특보 등) | ✅ |
| C3 | **캐릭터 교체 버튼** (홈 화면 내) | ✅ |
| C4 | **날씨 세부 정보 표시** (습도/풍속/강수확률) | ⚠️ (데이터는 있음, UI 미표시) |
| C5 | **UI 사운드 이펙트** | ⚠️ (assets 확보, 미적용) |

#### WON'T (이번 릴리스 제외)
| ID | 항목 | 이유 |
|----|------|------|
| W1 | 다국어 (한국어 외) | 학습 범위, 한국어만 |
| W2 | 사용자 계정/인증/멀티유저 | 로컬 개인 앱 |
| W3 | 운동 / 수집 탭 | IA에 자리만, 미구현 |
| W4 | 오프라인(로컬 LLM) 모드 | 서버 LLM 전제 |
| W5 | iOS 최적화 | Android 우선 |

---

## 2. 기획서 — 화면 설계 & 디자인 시스템

### 2.1 디자인 방향 (Design Language)
- **다크 + 네온**: 어두운 배경 위에 **네온 민트(`#00E676`)** 포인트로 생동감
- **글래스모피즘**: 반투명 카드 + `BackdropFilter` 블러(15)로 배경(날씨)과 UI 구분
- **몰입형 장면**: 계절/날씨에 따라 **배경이미지 + 캐릭터 의상**이 바뀌는 "실시간 장면"
- **음성 중심 UX**: 텍스트는 보조, **문장별 음성 재생**이 핵심 피드백 (타이핑 애니메이션으로 동기)

### 2.2 디자인 시스템 (Design Tokens)

**Color**
| Token | 값 | 용도 |
|-------|----|------|
| `bg` | `#121212` | 기본 배경 |
| `surface` | `#1E1E1E` | 바텀 내비 배경 |
| `accent` | `#00E676` | 포인트/선택/CTA (네온 민트) |
| `text-1` | `#FFFFFF` | 주요 텍스트 |
| `text-2/3/4` | `white54 / white38 / white24` | 보조 텍스트 위계 |
| `glass-fill` | `white 0.05~0.12` | 카드/칩 배경 |
| `glass-stroke` | `white 0.1~0.3` | 카드/입력창 테두리 |

**Typography** — `Noto Sans KR` (Google Fonts)
| 용도 | 스타일 |
|------|--------|
| 화면 제목 | 24 / Bold |
| 섹션 제목 | 13 / Bold / letterSpacing 1.2 |
| 본문 | 15~16 |
| 태그/보조 | 12 |

**Shape / Corner Radius**
| 용도 | 반지름 |
|------|--------|
| 카드 (설정 등) | 14 |
| 태그/칩 | 20 |
| 채팅 입력창 | 30 (fully rounded) |
| 캐릭터 교체 버튼 | 원형 (52×52) |

**Surface / Motion**
- Surface: 글래스 (블러 15 + 반투명)
- 캐릭터: **호흡(idle) 애니메이션** 3s 반복 (파트별 상하 offset)
- 텍스트: **타이핑 애니메이션** 50ms/자 (재생 문장과 동기)
- 바텀 내비: 하단→상단 **그라디언트 페이드** (black 0.85 → 0.3 → 투명)

### 2.3 화면 설계 (Screen Design)

#### 홈 (Home) — 핵심 화면
레이아웃: `Stack`(전체 확장)
| 레이어 | 요소 | 설명 |
|--------|------|------|
| 1 | 날씨 배경 | `assets/backgrounds/{season}/{weather}_{angle}.png` (BoxFit.cover, 실패 시 기본 배경+이모지) |
| 2 | 캐릭터 | 하단 중앙, 레이어드 파트 + 호흡 애니메이션, 의상은 (계절+날씨) 자동 선택 |
| 3 | 캐릭터 교체 버튼 | 우측 원형 — 이모지 + swap 아이콘, 탭 시 캐릭터 순환 |
| 4 | AI 응답 텍스트 | 타이핑 애니메이션 (재생되는 문장만큼 표시) |
| 5 | 채팅 입력 | 하단 글래스 입력창 (hint "무엇이든 물어보세요..."), send 버튼 (로딩 중 spinner) |

상태
- **초기화**: 날씨 조회 → 캐릭터/의상 로드 (완료 전 `CircularProgressIndicator`)
- **Fallback**: `is_fallback=true`면 실제 수치를 숨기고 "확인 불가" 톤으로 처리

인터랙션
```
입력 → ChatViewModel.sendMessage(message, location, weather)
     → ChatService(POST /chat, SSE) → 문장별 {text, audio}
     → AudioQueueService(큐 추가) → 재생 → 타이핑 애니메이션 동기
```

#### 설정 (Settings)
- **캐릭터 선택** 리스트 — 이모지·이름·"의상 N종"·선택 시 `#00E676` 테두리+체크
- **현재 의상** 정보 — 의상 이름 + `계절/날씨` 태그 칩

#### 운동 / 수집 (준비 중)
- 빈 화면 — 아이콘 + "준비 중입니다" (IA 자리만)

### 2.4 캐릭터 시스템 (Weather-reactive Character)
- `CharacterProfile`(id·이름·이모지·의상 목록) → `CharacterOutfit`(계절·날씨·경로·파트)
- **의상 선택 우선순위**: `(계절+날씨)` > `계절` > `날씨` > 첫 의상
- **레이어드 렌더링**: `parts_info.json` 기반 파트 위치/크기 (canvas 기준)
- **날씨 enum**: `clear / rain / snow / cloudy` (서버 `condition_code` 매핑, `unknown`→`clear`)
- **계절 계산**: 월 기반 (3–5 spring / 6–8 summer / 9–11 autumn / else winter)

---

## 3. IA (정보구조도)

### 3.1 화면 트리 (Navigation)
```
WeatherExer App
└── MainNavigation  (BottomNavigationBar, 4 tabs — 상태: _currentIndex)
    ├── [0] 홈 (HomeScreen)            ✅ 구현
    │     ├── 날씨 배경      (계절 / 날씨 / 앵글)
    │     ├── 캐릭터          (의상 자동 교체 + 호흡 애니메이션)
    │     ├── 캐릭터 교체 버튼
    │     ├── AI 응답 텍스트   (타이핑 애니메이션, 음성 동기)
    │     └── 채팅 입력        (텍스트 전송)
    ├── [1] 운동 (_EmptyScreen)        ⚠️ 준비 중
    ├── [2] 수집 (_EmptyScreen)        ⚠️ 준비 중
    └── [3] 설정 (SettingsScreen)      ✅ 구현
          ├── 캐릭터 선택    (리스트)
          └── 현재 의상 정보
```

### 3.2 전역 상태 (Global State — MultiProvider)
```
MaterialApp
└── MultiProvider
    ├── CharacterService  (ChangeNotifier)  → 캐릭터/의상 상태, initialize(), select/next
    └── ChatViewModel     (ChangeNotifier)  → 채팅/오디오 상태, sendMessage()
              └── (내부) ChatService + AudioQueueService
```

### 3.3 데이터/상태 플로우
```
[홈 초기화]
 WeatherService.getWeather() ──(GET /weather)──► FastAPI ──► KMA
     └► CharacterService.initialize(season, condition) ──► 의상/배경/캐릭터 로드

[채팅]
 채팅 입력
   └► ChatViewModel.sendMessage(message, location, weather)
        └► ChatService.sendChatMessage ──(POST /chat, SSE)──► FastAPI
             └► (서버) KMA→(키워드→웹검색)→LLM 스트림→문장 분할→TTS
        └► 문장별 {text, audio(base64 WAV)} 수신
             └► AudioQueueService.addAudioChunk
                  └► player.currentIndexStream ──► 타이핑 애니메이션 동기
```

### 3.4 네이티브/플랫폼 리소스
```
Android (android/app/src/main/AndroidManifest.xml)
├── INTERNET               ✅
├── ACCESS_NETWORK_STATE   ✅
└── 위치 권한              ❌ 부재 (실기기 GPS 날씨 시 추가 필요)

Assets
├── assets/audio/ (sound_effect)
├── assets/characters/{charId}/{season}_{condition}_{style}/  (parts_info.json + 파트 이미지)
└── assets/backgrounds/{season}/{weather}_{angle}.png
```

---

## 4. 기술스택

> 아래는 WeatherExer **실제 채택 스택**입니다. (Kotlin/Spring/PostgreSQL/JWT 기반 예시를 참고 형식만 차용, 실제 구성은 다름)

### 4.1 프론트엔드 — Flutter (안드로이드 우선)
| **항목** | **목적** | **상세 기술 (채택)** |
| --- | --- | --- |
| **언어** | 클라이언트 개발 언어 | **Dart** (SDK `^3.11.5`) |
| **프레임워크** | 크로스플랫폼 UI | **Flutter** (Android 우선) |
| **아키텍처** | 클라이언트 구조 패턴 | **MVVM** (ViewModel + Service 계층) |
| **상태 관리** | UI/비즈니스 로직 | **Provider (ChangeNotifier)** — `provider ^6.1.2` |
| **비동기 처리** | 스트림/호출 | **Dart async/await + Stream** (SSE 파싱) |
| **REST/실시간** | 채팅 전송·수신 | **http `^1.6.0` + SSE**(Server-Sent Events) 스트리밍 |
| **오디오 재생** | 문장별 TTS 재생 | **just_audio `^0.10.6`** (ExoPlayer/Android) + **audioplayers `^6.7.1`** |
| **위치** | GPS 날씨 (예정) | **geolocator `^14.0.2`** (권한 미설정) |
| **로컬 저장** | 캐릭터 데이터 | **hive `^2.2.3` / hive_flutter** |
| **설정** | API URL 등 | **flutter_dotenv `^6.0.1`** (.env) |
| **폰트** | 한글 타이포 | **google_fonts `^8.1.0`** (Noto Sans KR) |
| **파일 경로** | 오디오 임시파일 | **path_provider `^2.1.6`** |
| **테스트** | — | **flutter_test** (dev) |

### 4.2 백엔드 — FastAPI
| **항목** | **목적** | **상세 기술 (채택)** |
| --- | --- | --- |
| **언어/런타임** | 서버 개발 언어 | **Python 3.x** |
| **프레임워크** | 핵심 구조 + SSE | **FastAPI (async) + uvicorn** |
| **LLM 연동** | 답변 생성 | **llama.cpp llama-server** (OpenAI 호환 `/v1/chat/completions`) |
| **TTS 연동** | 음성 합성 | **GPT-SoVITS `api_v2.py`** (`POST /tts`) |
| **날씨 소스** | 실시간 기상 데이터 | **기상청(KMA) 공공데이터 API** + TTL 캐시 |
| **웹검색** | 최신 정보 | **duckduckgo_search (DDGS)** |
| **HTTP 클라이언트** | 비동기 호출 | **httpx** (async + `asyncio.to_thread`) |
| **설정** | 환경변수 | **python-dotenv** (.env) |
| **로깅** | 운영 로그 | **logging** (StreamHandler + UTF-8 FileHandler → `server.log`) |
| **스키마 검증** | 요청/응답 | **Pydantic** |

### 4.3 AI / 모델 인프라
| **항목** | **상세 기술 (채택)** |
| --- | --- |
| **LLM** | **Qwen** — 현재 **Qwen3.8-27B (UD-Q4_K_M GGUF, 15.3GB)** · Cline 공용 (원본 Qwen2.5-14B) |
| **LLM 서버** | **llama.cpp** (llama-server, OpenAI 호환) |
| **추론 모드** | `chat_template_kwargs: {"enable_thinking": false}` (추론 모델 `content` 비어짐 방지) |
| **TTS** | **GPT-SoVITS** — "나히다"(한국어 여성) 보이스, 48kHz mono WAV |
| **GPU** | **NVIDIA RTX 5090** (VRAM 32GB) |
| **메모리 제약** | Qwen3.8 + Qwen2.5 동시 GPU 로드 불가 → **Qwen3.8 1개 공용** |

### 4.4 DevOps / 인프라
| **항목** | **목적** | **채택** | **상태** |
| --- | --- | --- | --- |
| **기동** | 서버 시작/종료/상태 | **PowerShell 스크립트** (`start_api.ps1`/`status.ps1`/`stop_servers.ps1`) | 구현 완료 |
| **컨테이너** | — | 미사용 (로컬 직접 실행) | — |
| **CI/CD** | 자동화 | N/A | 미구현 |
| **버전 관리** | 이력 추적/공유 | **Git / GitHub** | 운영 중 |
| **배포** | 클라이언트 접속 | **로컬** (에뮬레이터 `10.0.2.2` / 실기기 LAN IP) | 로컬 |

### 4.5 보안 / 설정
| **항목** | **채택** | **상태** |
| --- | --- | --- |
| **인증** | 없음 (로컬/개인 앱, 단말 간 직접 통신) | N/A |
| **KMA API Key** | `.env`(`KMA_API_KEY`) — 서버에서 호출, **클라이언트 미노출** | 구현 완료 |
| **HTTPS** | 미구현 (로컬 HTTP) | 미구현 |
| **비밀 관리** | 로컬 `.env` | 미구현 (클라우드 미사용) |

---

## 5. API 명세서

> **Base URL**: `http://{SERVER}:8000` — 에뮬레이터 `10.0.2.2`, 실기기 LAN IP (`.env`의 `BACKEND_URL`)
> 인증 없음 (로컬 개인 앱).

### 5.1 날씨 조회 (Weather — `GET /weather`)

| 항목 | 내용 |
| --- | --- |
| **API 개요** | 서버가 기상청(KMA) 단기예보를 조회·정규화한 **현재/오늘 날씨**를 반환. 실패 시 `is_fallback=true`의 명시적 대체 데이터를 반환. |
| **인증/인가** | 공개 API (인증 불필요) |
| **메서드/경로** | `GET /weather` |

**Request**

| 파라미터 | 타입 | 필수 여부 | 설명 |
| --- | --- | --- | --- |
| `location_id` | `String` (query) | 선택 | 기본 `bucheon-simgok1` (부천 심곡1동) |

**Response**

| 항목 | 내용 |
| --- | --- |
| **성공 응답** | **`HTTP 200 OK`** |
| **실패 응답** | `500` (기상청/내부 오류 — 이 경우에도 fallback 객체 반환) |

| 응답 바디 필드 | 타입 | 설명 |
| --- | --- | --- |
| `location_id` | `String` | 위치 ID |
| `location_name` | `String` | `"부천시"` |
| `latitude` / `longitude` | `Number` | 좌표 |
| `source` | `String` | `"kma"` / `"fallback"` |
| `is_fallback` | `Boolean` | `true`면 실제 데이터 아님 (UI/LLM이 구분) |
| `observed_at` | `String` | `"2026-09-30 02:00"` |
| `current.temperature` | `Number` | 현재 기온 (℃) |
| `current.feels_like` | `Number?` | 체감 기온 (℃) |
| `current.condition_korean` | `String` | `"맑음"` 등 |
| `current.condition_code` | `String` | `"clear"`/`"rain"`/`"snow"`/`"cloudy"`/`"unknown"` |
| `current.humidity` | `Integer?` | 습도 (%) |
| `current.wind_speed` | `Number?` | 풍속 (m/s) |
| `current.wind_direction` | `Integer?` | 풍향 (degree) |
| `current.precipitation_korean` | `String` | `"강수 없음"` 등 |
| `today.temp_min` / `today.temp_max` | `Number?` | 오늘 최저/최고 기온 (℃) |
| `today.precip_prob_max` | `Integer?` | 오늘 최대 강수확률 (%) |

**Request / Response Example**

```bash
curl http://{SERVER}/weather
```
```json
{
  "location_id": "bucheon-simgok1",
  "location_name": "부천시",
  "latitude": 37.503,
  "longitude": 126.778,
  "source": "kma",
  "is_fallback": false,
  "observed_at": "2026-09-30 02:00",
  "current": {
    "temperature": 12.3,
    "feels_like": 10.8,
    "condition_korean": "맑음",
    "condition_code": "clear",
    "humidity": 62,
    "wind_speed": 2.1,
    "wind_direction": 315,
    "precipitation_korean": "강수 없음"
  },
  "today": { "temp_min": 8.5, "temp_max": 17.2, "precip_prob_max": 10 }
}
```

> **Fallback 예시** (KMA 실패): `source:"fallback"`, `is_fallback:true`, `current.condition_code:"unknown"`, 수치 필드들은 `null`.

### 5.2 음성 채팅 (Chat — `POST /chat`) — SSE 스트리밍

| 항목 | 내용 |
| --- | --- |
| **API 개요** | 사용자 메시지를 받아 (1) KMA 날씨 조회 (2) 필요 시 웹검색 (3) LLM 답변을 **문장 단위로 TTS 음성(base64 WAV)과 함께 SSE**로 스트리밍. |
| **인증/인가** | 공개 API (인증 불필요) |
| **메서드/경로** | `POST /chat` |
| **응답 타입** | `text/event-stream` (SSE) |

**Request**

| 파라미터 | 타입 | 필수 여부 | 설명 |
| --- | --- | --- | --- |
| `Content-Type` | `String` | 필수 | `application/json` |

| 요청 바디 필드 | 타입 | 필수 여부 | 설명 |
| --- | --- | --- | --- |
| `user_message` | `String` | 필수 | 사용자 메시지 (필수 누락 시 `422`) |
| `location` | `String` | 선택 | 기본 `"위치 미지정"` |
| `weather_condition` | `String` | 선택 | 기본 `"알 수 없음"` |

**Response**

| 항목 | 내용 |
| --- | --- |
| **성공 응답** | **`HTTP 200 OK`** (SSE 스트림) |
| **실패 응답** | `422` (필드 누락), LLM/네트워크 오류 시 **에러 문장 1개** 전송 |

**SSE 이벤트 형식**

| 이벤트 | 형식 | 설명 |
| --- | --- | --- |
| 문장 청크 | `data: {"text":"...","audio":"<base64 WAV>"}` | 문장 단위 텍스트 + 해당 문장 TTS(48kHz mono WAV, base64) |
| 종료 | `data: [DONE]` | 스트림 종료 시그널 |

**Request Example**

```bash
curl -N -X POST http://{SERVER}/chat \
  -H "Content-Type: application/json" \
  -d '{
    "user_message": "오늘 날씨가 어때?",
    "location": "경기도 부천시",
    "weather_condition": "맑음"
  }'
```

**Response Example (SSE 스트림)**

```
data: {"text":"오늘 부천은 맑겠어요.","audio":"UklGRi..."}

data: {"text":"현재 기온은 12.3도이고, 체감온도는 10.8도예요.","audio":"UklGRj..."}

data: [DONE]
```

> **내부 처리 흐름**: KMA 조회(`asyncio.to_thread`) → 키워드 추출(LLM, `enable_thinking:false`) → (필요 시) DDGS 웹검색 → 메인 채팅(LLM 스트림, `enable_thinking:false`) → 문장 분할(`[.!?]`) → `clean_text_for_tts`(한글/숫자/문장부호만) → 문장별 TTS → SSE.

---

## 6. 개발과정 / 문제해결

### 6.1 파이프라인
```
Flutter(앱) ──SSE──► FastAPI(8000) ──► LLM: llama.cpp/Qwen(8080)
                                   ├─► TTS: GPT-SoVITS(9880, 48kHz WAV)
                                   └─► 날씨: 기상청(KMA) + TTL 캐시
```

### 6.2 주요 마일스톤
1. **신형 PC(RTX 5090) 이전** 및 AI 스택 복구 (venv, llama.cpp, GPT-SoVITS)
2. **TTS(GPT-SoVITS) 기동** — "나히다" 보이스, 48kHz mono WAV 출력 확인
3. **FastAPI `/chat` SSE** 구축 — 문장별 텍스트+오디오 스트리밍
4. **Flutter 클라이언트** — 홈/설정/캐릭터(의상·배경)/오디오 큐
5. **서버측 KMA 날씨 통합** — `GET /weather` + `/chat` 컨텍스트 주입 (E2E)
6. **E2E 검증** — "오늘 날씨가 어때?" → KMA 실데이터 기반 답변 + 문장별 TTS

### 6.3 문제해결 로그 (Problem → Cause → Fix)
| # | 증상 | 원인 | 해결 |
|---|------|------|------|
| 1 | TTS `400` | SoVITS i18n 로그(간체중문)가 Windows cp949 stdout에서 `UnicodeEncodeError` | `PYTHONUTF8=1` + `PYTHONIOENCODING=utf-8` 재기동 |
| 2 | TTS 미동작 | `run_api.bat`이 옛 `api.py` 실행 | `api_v2.py` 직접 실행 |
| 3 | `/chat` `422` | (a) 필드명 `user_message` (b) CMD quoting (c) PowerShell `curl` alias | `curl.exe` / PowerShell 네이티브 `Invoke-RestMethod` |
| 4 | **빈 스트림** (텍스트/오디오 없음, `[DONE]`만) | **Qwen3.8 추론모델** — 토큰이 `reasoning_content`로 빠져 `content` 비어짐 | LLM payload 2곳에 `chat_template_kwargs:{"enable_thinking":false}` |
| 5 | FastAPI 로그 한글 깨짐 | `print`가 cp949 콘솔로 깨짐 | `logging.FileHandler(encoding="utf-8")` 이중 기록 → `server.log` |
| 6 | Flutter `Bad state` | `finally`에서 이미 소비된 스트림 drain | drain 제거 + `cancelActiveStream` try/catch |
| 7 | 오디오 **중간 문장 누락** | 청크 재생 완료 시 파일 즉시 삭제 → 인덱스 미스얼라인 | 재생 완료/큐 정리 시에만 **일괄 삭제** |
| 8 | **첫 문장 앞 잘림** | 에뮬레이터 오디오 HAL 워밍업 첫 버퍼 드롭 | 0.3초 무음 WAV **워밍업** |
| 9 | "날씨를 알 수 없다" | 8000 포트에 **구버전 FastAPI**(날씨 미적용) 잔존 | stale 프로세스 종료 후 venv로 재기동 |
| 10 | 이벤트루프 블로킹 위험 | KMA `httpx`가 blocking | `asyncio.to_thread(weather_service.get_weather)` |
| 11 | 위치 기반 미작동 | `AndroidManifest`에 위치 권한 부재 | 기본값(부천) 사용 (실기기 시 권한 추가 예정) |

### 6.4 현재 상태 (2026-09-30)
- **E2E 정상**: `POST /chat` "오늘 날씨가 어때?" → KMA 실데이터 기반 답변 + **12 문장 TTS** (HTTP 200, SSE)
- **서버**: FastAPI(8000) · LLM(8080, Qwen3.8) · TTS(9880)
- **기존 APK 그대로 동작** — 이번 수정은 전부 **서버측**이라 Flutter 재빌드 불필요

### 6.5 다음 단계 / 미해결
- **실기기 테스트** — 같은 LAN + PC 방화벽 `8000` 인바운드 허용
- **위치 권한** — `AndroidManifest`에 location 권한 + `geolocator` 실제 사용
- **성능** — 날씨 질문만 웹검색 스킵, TTS 문장별 병렬, 첫 토큰 지연 축소
- **기능** — 운동/수집 탭, 날씨 세부 정보 UI(C4), 사운드 이펙트(C5)