# WeatherExer

> **간단 소개**
> 캐릭터가 사용자와 **대화하며** 날씨 정보를 알려주는 **한국어 음성 AI 날씨 앱**입니다.
> 계절·날씨에 따라 캐릭터의 **의상과 배경**이 바뀌고, 사용자의 질문에 ** 기상청 데이터**를 바탕으로 **목소리로** 답변합니다.
>
> **개발 배경**
> "날씨만 확인하고 종료"하는 날씨 앱이 아닌, 캐릭터와 **대화하며 상호작용**하는 재미있는 날씨 경험을 만들고 싶었습니다.
>
> **개발 기간**
> "2026.06 - 현재
>

## 주요 기능 (Main Features)

> **날씨 확인 & 음성 대화**

1. 홈 화면에서 **움직이고 말하는 캐릭터**와 채팅을 통해 날씨·일상 이야기를 나눌 수 있습니다.
2. 날씨 답변은 ** 기상청(KMA) 데이터**에 기반합니다.
3. 답변은 **문장 단위로 한국어 음성(TTS)**으로 재생되고, 텍스트 타이핑 애니메이션과 **동기**됩니다.

> **날씨 반응형 캐릭터 & 배경**

1. 계절과 날씨(맑음 / 비 / 눈 / 구름)에 따라 캐릭터 **의상**과 화면 **배경**이 자동으로 바뀝니다.
2. 설정 화면에서 **캐릭터를 선택**하고 현재 **의상 정보**를 확인할 수 있습니다.

## 시연 및 데모 (Demo / Screenshot)

> 📸 스크린샷
>
> <img width="410" height="911" alt="스크린샷 2026-09-30 212013" src="https://github.com/user-attachments/assets/d8804baa-0b21-4599-bbdd-0777c29ff072" />
>
> 동영상
>
> 데모 영상은 Notion 프로젝트 페이지에서 확인할 수 있습니다.
> https://hissing-pineapple-d11.notion.site/WeatherExer-AI-3ea0f219a3fd80a58eefc6eb066cc1ca


## 설치 및 실행 방법 (Installation & Execution)

### 시스템 요구 사양 (System Requirements)

로컬 환경에서 LLM(대형 언어 모델)과 고성능 TTS 서버를 동시에 구동하므로, 안정적인 실시간 음성 합성을 위해 **NVIDIA GPU** 환경이 필수적입니다.

| 항목 | 최소 사양 (Minimum) | 권장 사양 (Recommended) |
| :--- | :--- | :--- |
| **OS** | Windows 10 / 11 (64-bit) | Windows 11 (64-bit) |
| **GPU** | NVIDIA GeForce RTX 3060 (12GB) | NVIDIA GeForce RTX 4080 (16GB) 이상 |
| **VRAM** | **최소 12GB 이상** (일부 （RAM） 오프로드 필수) | **16GB ~ 24GB 이상** (전체 GPU 추론 가능) |
| **CPU** | Intel Core i5 / AMD Ryzen 5 (AVX2 지원) | Intel Core i7 / AMD Ryzen 7 이상 |
| **RAM** | 16 GB | 32 GB 이상 (Flutter 에뮬레이터 구동 고려) |
| **Storage** | 50GB 이상의 여유 공간 | NVMe M.2 SSD (모델 빠른 로딩용) |

> 💡 **참고 (VRAM 점유 예측):** 
> * Qwen 2.5 14B Q4_K_M 추론 시 약 `9.5GB` 점유
> * GPT-SoVITS 한국어 음성 추론 시 약 `5.5GB` 점유
> * 두 모델 동시 구동 시 순수 AI 엔진으로만 **최소 15GB 내외의 VRAM**이 요구됩니다. VRAM
>

> * Windows + GPU PC 권장. **서버 3개 + Flutter 앱** 구성입니다

### 기상청 API 발급 받기
https://www.data.go.kr/data/15084084/openapi.do 에서 활용 신청을 하고 API키를 발급받습니다 
이후 .env에 KMA_API_KEY 키 등으로 사용하면 됩니다.

### 1) 서버 (백엔드)

| 서버 | 포트 | 역할 |
| --- | --- | --- |
| `llama-server` (llama.cpp) | `8080` | LLM (Qwen) 추론 — OpenAI 호환 API |
| GPT-SoVITS | `9880` | 한국어 TTS (나히다 보이스, 48kHz mono WAV) |
| FastAPI (`main.py`) | `8000` | 중계 서버 — `/chat`(SSE), `/weather`(KMA) |

```powershell
# (각각 별도 터미널/창에서)
E:\WheaterExer_AI\start_tts.ps1   # TTS      :9880
E:\WheaterExer_AI\start_api.ps1   # FastAPI  :8000  (venv python 사용, PYTHONUTF8=1 자동)
# LLM(llama-server :8080)은 llama.cpp로 별도로 기동

E:\WheaterExer_AI\status.ps1      # 9880 / 8000 / 8080 LISTENING 여부 확인
E:\WheaterExer_AI\stop_servers.ps1# 서버 종료
```

- `Server\.env`: `LLM_URL`, `TTS_URL`, `KMA_API_KEY` 등 설정
- FastAPI는 반드시 **venv python** 사용 (`start_api.ps1`이 처리)

### 2) Flutter 앱 (클라이언트)

```bash
cd <flutter_project>
flutter pub get
```

- `.env`의 `BACKEND_URL` 설정
  - 에뮬레이터: `http://10.0.2.2:8000`
  - 실기기: PC의 LAN IP (`http://<PC_IP>:8000` — PC 방화벽에서 `8000` 인바운드 허용 필요)

```bash
flutter run
```

> 📖 상세한 아키텍처 · API · 개발 이력은 **[기획서](./WHEATEREXER_기획서.md)** 참고.

## 기술 스택 (Tech Stacks)

**런타임 (구현)**

| 구분 | 기술 |
| --- | --- |
| 클라이언트 | **Flutter (Dart)** — MVVM · Provider · just_audio · geolocator · hive |
| 백엔드 | **FastAPI (Python)** — SSE 스트리밍 · Pydantic |
| LLM | **llama.cpp (llama-server) + Qwen** (OpenAI 호환 API) |
| TTS | **GPT-SoVITS** (한국어, 48kHz mono WAV) |
| 날씨 | **기상청(KMA) 공공데이터 API** + TTL 캐시 |
| 웹검색 | **DuckDuckGo (DDGS)** |

**에셋 / 콘텐츠 제작**

개발/테스트: Qwen3.8 27B Q4_K_M
앱 서비스: Qwen2.5 14B Instruct Q4_K_M
