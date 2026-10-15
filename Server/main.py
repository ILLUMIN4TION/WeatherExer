from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

import datetime
from duckduckgo_search import DDGS
import re
import httpx
import logging
import json
import base64
import asyncio
from collections import deque
from dotenv import load_dotenv
import os

# 기상청 날씨(단기예보) 모듈 - KMA 호출/파싱/캐싱은 main.py 밖에서 분리 관리
from weather.service import get_weather_service
from weather.locations import DEFAULT_LOCATION_ID

# ---------------------------------------------------------
# [환경변수 로드 (.env)]
# ---------------------------------------------------------
current_dir = os.path.dirname(os.path.abspath(__file__))
dotenv_path = os.path.join(current_dir, '.env')
load_dotenv(dotenv_path)

# 로깅: 콘솔(stdout) + UTF-8 로그 파일(server.log) 이중 기록
# - FileHandler가 파일을 Python 쪽에서 UTF-8으로 직접 쓰므로,
#   PowerShell 파이프라인(Tee-Object)이 Python의 UTF-8 출력을 cp949로
#   오해석해 로그 한글이 깨지던 문제를 회피한다.
_log_file = os.path.join(current_dir, "server.log")
logging.basicConfig(
    level=logging.INFO,
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(_log_file, encoding="utf-8", mode="a"),
    ],
)
logger = logging.getLogger(__name__)

app = FastAPI(title="WeatherExer Backend API")

# ---------------------------------------------------------
# [서버 인프라 설정]
# ---------------------------------------------------------
LLM_URL = os.getenv("LLM_URL", "http://127.0.0.1:8080/v1/chat/completions")
TTS_URL = os.getenv("TTS_URL", "http://127.0.0.1:9880/tts")
REF_AUDIO_PATH = os.getenv(
    "TTS_REF_AUDIO_PATH", 
    "C:/TTS/workspace/sliced/kr_nahida.mp3_0000217920_0000427520.wav"
)
PROMPT_TEXT = os.getenv(
    "TTS_PROMPT_TEXT", 
    "내 이름은 나히다, 아이처럼 보이지만 그 어떤 어른보다도 이 세상을 잘 알고 있지."
)

API_PORT = int(os.getenv("API_PORT", "8000"))
API_HOST = os.getenv("API_HOST", "0.0.0.0")

logger.info(f"🔧 LLM URL: {LLM_URL}")
logger.info(f"🔧 TTS URL: {TTS_URL}")
logger.info(f"🔧 API Server: {API_HOST}:{API_PORT}")

# 날씨(기상청) 서비스 싱글톤 - .env(KMA_API_KEY, WEATHER_CACHE_TTL, WEATHER_LOCATION) 기반
weather_service = get_weather_service()
logger.info(f"🌦️  날씨 서비스 준비 완료 (기본 위치: {DEFAULT_LOCATION_ID})")

# ---------------------------------------------------------
# [대화 히스토리 (인메모리, 최소 세션)]
# ---------------------------------------------------------
# "그날", "아까 말한 날", "방금 말한 날씨" 같은 지시어를 해석하기 위해
# 최근 N개 메시지(user/assistant)를 LLM 요청에 함께 전달한다.
# 인메모리 전용: 서버 재시작 시 초기화. DB/RAG/장기 메모리는 사용하지 않는다.
MAX_HISTORY_MESSAGES = 8  # user+assistant 4턴
_conversation_history: deque = deque(maxlen=MAX_HISTORY_MESSAGES)

# 플러터 앱이 POST로 보내는 JSON 데이터를 매핑할 모델
class ChatRequest(BaseModel):
    user_message: str
    location: str = "위치 미지정"
    weather_condition: str = "알 수 없음"

SYSTEM_PROMPT = """
당신은 날씨와 일상 대화를 돕는 친절한 조력자입니다.
[엄격한 제약 사항 - 반드시 지켜야 합니다]
1. 언어: 답변의 모든 문장은 무조건 한국어(한글)로만 작성하세요.
   - 중국어(한자) 문자는 단 하나의 글자도 섞일 수 없습니다. 한자가 섞여 나오는 것은 절대 금지입니다.
   - 과학·천체·우주 용어도 반드시 한국어 표기로만 쓰세요.
     (예: 수성, 금성, 지구, 화성, 목성, 토성, 천왕성, 해왕성 / 태양, 행성, 은하, 항성, 위성)
2. 말투: 부드러운 존댓말(해요체)를 사용하세요.
3. 정보: 제공된 실시간 웹 검색 결과가 있다면 그것을 최우선으로 참고하여 대답하세요.
4. 목록: 번호(1. 2. 3.) 뒤에는 반드시 한국어 항목명을 함께 쓰세요. (예: "1. 화성")
5. 대화 맥락: 현재 질문 외에 이전 대화(user/assistant 메시지)가 함께 주어질 수 있습니다.
   '그날', '아까 말한 날', '방금 말한 날씨' 같은 지시어가 있으면 반드시 이전 대화에
   나온 날짜와 내용을 기준으로 해석하여 답하세요. (예: 직전 대화에서 10월 3일을
   이야기했다면 '그날'은 10월 3일을 가리킵니다.)
"""

def clean_text_for_tts(text: str) -> str:
    cleaned = re.sub(r'[^가-힣0-9\s\.\,\!\?]', '', text)
    cleaned = re.sub(r'\s+', ' ', cleaned)
    cleaned = re.sub(r'\.+', '.', cleaned)
    return cleaned.strip()

def normalize_weather_numbers(text: str) -> str:
    """[TTS 수치 수정] 날씨 수치를 TTS가 자연스럽게 읽는 형태로 정규화 (TTS 전송 직전 적용).

    - 단위(도/℃)가 붙은 정수값: 22.0도 → 22도, 18.0℃ → 18℃ (22.5 같은 소수는 그대로 유지)
    - 온도·습도·강수 맥락의 정수값(단위 없음): '기온은 22.0입니다' → '기온은 22입니다'
    - 퍼센트: 60% → 60퍼센트, 60.0% → 60퍼센트
    - 날씨 맥락이 아닌 일반 숫자(예: '22.0이라는 숫자')는 절대 변경하지 않는다.
    """
    # 1) 온도 단위(도/℃)가 붙은 정수값 → .0 제거 (22.0도 → 22도)
    text = re.sub(r'([0-9]+)\.0+([ 	]*)(도|℃)', lambda m: m.group(1) + m.group(2) + m.group(3), text)
    # 2) 날씨 맥락(기온/온도/체감/확률/습도/풍속)의 정수값 → .0 제거 (단위 없이 나온 경우)
    text = re.sub(
        r'((?:기온|온도|체감|강수확률|확률|습도|풍속)[^0-9]{0,10}?)([0-9]+)\.0+(?![0-9.])',
        lambda m: m.group(1) + m.group(2),
        text,
    )
    # 3) 퍼센트 → '퍼센트' (60% → 60퍼센트, 60.0% → 60퍼센트)
    text = re.sub(r'([0-9]+)\.0+[ ]*%', lambda m: m.group(1) + '퍼센트', text)
    text = re.sub(r'([0-9]+)[ ]*%', lambda m: m.group(1) + '퍼센트', text)
    return text

async def generate_tts_audio(text: str) -> str:
    if not text:
        return ""
        
    async with httpx.AsyncClient() as client:
        try:
            params = {
                "text": text,
                "text_lang": "ko",
                "ref_audio_path": REF_AUDIO_PATH,  
                "prompt_text": PROMPT_TEXT,        
                "prompt_lang": "ko"                
            }
            response = await client.get(TTS_URL, params=params, timeout=10.0)
            response.raise_for_status()
            audio_base64 = base64.b64encode(response.content).decode('utf-8')
            return audio_base64
        except Exception as e:
            logger.error(f"TTS 생성 실패 (TTS 서버 연결 오류): {e}")
            return ""

async def get_search_keyword(user_message: str, location: str) -> str:
    now = datetime.datetime.now()
    current_year = now.strftime("%Y년")
    current_time_str = now.strftime("%Y년 %m월 %d일")
    
    payload = {
        "model": "qwen2.5-14b-instruct-q4_k_m",
        "messages": [
            {
                "role": "system", 
                "content": f"""당신은 인터넷 검색 여부를 판단하는 검색 키워드 추출기입니다. 
현재 날짜는 {current_time_str}입니다.
사용자의 질문이 다음 중 하나라도 해당한다면, 검색 엔진에 입력할 '짧고 명확한 핵심 키워드'를 작성하세요.
- 최신 정보, 뉴스, 날씨 (이 경우 '{location}' 포함)
- 특정 기업의 제품, 사양, 모델명 (예: 인텔 그래픽카드, 최신 스마트폰 등)

**[중요 규칙]** 질문에 '최근', '최신', '올해' 같은 단어가 포함되어 있거나 최신 동향을 묻는 질문이라면, 추출하는 키워드 맨 앞에 무조건 '{current_year}'을 포함시키세요. (예: {current_year} NVIDIA 소비자용 그래픽카드)

단순한 인사, 일상 대화, 감정 표현(예: "안녕", "기분 어때")처럼 정보 검색이 전혀 필요 없는 경우에만 오직 'NO'라고 대답하세요."""
            },
            {"role": "user", "content": user_message}
        ],
        "temperature": 0.0, 
        "max_tokens": 15,
        "chat_template_kwargs": {"enable_thinking": False},
        "stream": False 
    }
    
    async with httpx.AsyncClient() as client:
        try:
            logger.info(f"🧠 LLM 요청 전송: {LLM_URL}")
            response = await client.post(LLM_URL, json=payload, headers={"Content-Type": "application/json"}, timeout=5.0)
            response.raise_for_status()
            answer = response.json().get("choices", [])[0].get("message", {}).get("content", "").strip()
            
            logger.info(f"🧠 라우터 판단 결과(추출된 키워드): {answer} (원래 질문: {user_message})")
            return answer
        except Exception as e:
            logger.error(f"키워드 추출 중 오류: {e}")
            return "NO"

def perform_web_search(keyword: str) -> str:
    try:
        results = DDGS().text(keyword, max_results=5)
        if results:
            return "\n".join([f"- {r['title']}: {r['body']}" for r in results])
    except Exception as e:
        logger.error(f"검색 실패: {e}")
    return "검색 결과를 가져오지 못했습니다."

async def stream_generator(raw_user_message: str, location: str, weather_data=None):
    
    # 1. 스마트 키워드 추출
    search_keyword = await get_search_keyword(raw_user_message, location)
    search_keyword = search_keyword.strip() # 공백 제거
    
    # 0. 날씨 컨텍스트 (기상청 실데이터) - LLM 주입용
    weather_context = (
        weather_data.to_weather_context()
        if weather_data is not None
        else "[날씨 정보] 현재 날씨 데이터를 가져오지 못했습니다."
    )
    
    # 🔥 수정 1: 키워드가 아예 없는 빈 문자열("")일 때 검색 엔진이 뻗는 버그 완벽 차단
    if search_keyword and search_keyword.upper() != "NO":
        logger.info(f"🔍 웹 검색 진행 중... 검색어: [{search_keyword}]")
        search_info = perform_web_search(search_keyword)  
        
        now = datetime.datetime.now()
        current_time_str = now.strftime("%Y년 %m월 %d일 %H시 %M분")
        
        final_prompt = f"""[절대 규칙 및 실시간 컨텍스트]
현재 날짜/시간: {current_time_str}
기준 위치: {location}
{weather_context}
웹 검색 결과 요약본: {search_info}

[지시사항]
1. 당신의 과거 학습 데이터보다 위의 '웹 검색 결과 요약본'을 100% 신뢰하고 최우선으로 참고하세요.
2. 단, 날씨·기온·강수·바람 질문(오늘/내일/글피 등)에는 위의 '[날씨 정보]'(기상청 실데이터)를 최우선으로 사용하고, 웹 검색 결과와 충돌하면 웹 검색 결과를 무시하세요.
3. "실시간 검색을 할 수 없다", "미래 정보라 알 수 없다" 같은 시스템적인 변명이나 사과는 **절대** 하지 마세요. 당신은 이미 검색 결과를 받았습니다.
4. 만약 검색 결과 요약본 안에 구체적인 모델명이나 정답이 없다면, 억지로 지어내거나 변명하지 말고 "검색해 보았지만 구체적인 모델명은 본문에 가려져 있어서 바로 확인하기 어렵네요~" 처럼 아주 자연스럽고 친근한 대화체로 넘어가세요.
질문: {raw_user_message}"""
    else:
        logger.info(f"💬 웹 검색 없이 일상 대화 진행")
        final_prompt = f"{weather_context}\n\n[사용자 질문]\n{raw_user_message}"
        
    # [대화 맥락] 이전 대화(최근 N개) + 현재 질문을 LLM에 전달
    llm_messages = list(_conversation_history)
    llm_messages.append({"role": "user", "content": final_prompt})
    logger.info(f"🧠 LLM 스트리밍 요청: messages {len(llm_messages)}개 (이전 대화 {len(_conversation_history)}개 포함) {LLM_URL}")
    for m in llm_messages:
        _content = m["content"]
        logger.info(f"   📨 [{m['role']}] {_content[:60]}{'…' if len(_content) > 60 else ''}")
    payload = {
        "model": "qwen2.5-14b-instruct-q4_k_m", 
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            *llm_messages
        ],
        "temperature": 0.5,
        "frequency_penalty": 1.15,
        "max_tokens": 300,
        "chat_template_kwargs": {"enable_thinking": False},
        "stream": True 
    }
    
    # 🔥 수정 2: 서버에 SSE 통신을 명확하게 요구하도록 헤더 강화
    headers = {
        "Content-Type": "application/json",
        "Accept": "text/event-stream"
    }

    async with httpx.AsyncClient() as client:
        try:
            logger.info(f"🧠 LLM 스트리밍 요청 전송: {LLM_URL}")
            async with client.stream("POST", LLM_URL, json=payload, headers=headers, timeout=30.0) as response:
                response.raise_for_status()
                
                buffer = ""
                full_response = ""  # [대화 맥락] 완전한 답변을 누적해 턴 종료 시 히스토리에 저장
                # 🔥 수정 3: 엔터(\n) 단위로도 문장을 자르도록 청킹 강화
                # [TTS 수치 수정] '.'는 다음 글자가 숫자가 아닐 때만 문장 종결로 처리:
                # "22.5", "22.0" 같은 소수점 숫자는 청크를 분리하지 않고,
                # 실제 문장 끝의 '.'(뒤가 숫자가 아닌 경우)에서만 나누도록 최소 보완
                sentence_end_pattern = re.compile('(\.(?=[^0-9])|[?!\n])')

                async for line in response.aiter_lines():
                    if not line.strip():
                        continue
                        
                    if line.startswith("data: "):
                        data_str = line[len("data: "):].strip()
                        if data_str == "[DONE]":
                            break
                        
                        try:
                            data_json = json.loads(data_str)
                            choices = data_json.get('choices', [])
                            if not choices:
                                continue
                                
                            delta = choices[0].get('delta', {})
                            raw_content = delta.get('content', '')
                            
                            token = raw_content if raw_content else ""
                            buffer += token
                            full_response += token
                            # [청킹 버그 수정] 디버그 print(f"{token}") 제거.
                            # LLM이 한자/외국어 토큰을 섞어 보내면 이 print가 cp949 stdout에서
                            # UnicodeEncodeError를 던져, 아래 except->continue로 '문장 분할 로직' 자체가
                            # 건너뛰어지며 청크가 깨지던 원인이었음. stdout/stderr 인코딩은
                            # start_api.ps1 의 PYTHONUTF8=1 로 UTF-8을 보장한다.
                            
                            match = sentence_end_pattern.search(buffer)
                            if match:
                                split_index = match.end()
                                chunk = buffer[:split_index].strip()
                                buffer = buffer[split_index:].strip()
                                
                                clean_chunk = clean_text_for_tts(normalize_weather_numbers(chunk))
                                
                                if clean_chunk:
                                    logger.info(f"\n[청크 전송] -> TTS: {clean_chunk}")
                                    audio_b64 = await generate_tts_audio(clean_chunk)
                                    yield f"data: {json.dumps({'text': clean_chunk, 'audio': audio_b64})}\n\n"
                                    
                        except Exception as e:
                            # 🔥 수정 4: 파싱 에러 발생 시 무시하지 않고 로그를 남김!
                            logger.error(f"❌ JSON 파싱 에러: {e} | 원본 데이터: {data_str}")
                            continue
                    else:
                        # 🔥 수정 5: LLM 서버가 정상적인 data: 형태가 아닌 이상한 텍스트를 뱉을 때 추적용
                        logger.warning(f"⚠️ 예상치 못한 LLM 응답 (SSE 아님): {line}")
                            
                # 스트림 종료 후 버퍼에 남은 짧은 문장 처리
                if buffer.strip():
                    clean_chunk = clean_text_for_tts(normalize_weather_numbers(buffer.strip()))
                    if clean_chunk:
                        logger.info(f"\n[마지막 청크 전송] -> TTS: {clean_chunk}")
                        audio_b64 = await generate_tts_audio(clean_chunk)
                        yield f"data: {json.dumps({'text': clean_chunk, 'audio': audio_b64})}\n\n"
                        
                # [대화 맥락] 이번 턴을 히스토리에 저장 (정상 답변이 있을 때만, 최대 N개 유지)
                if full_response.strip():
                    _conversation_history.append({"role": "user", "content": raw_user_message})
                    _conversation_history.append({"role": "assistant", "content": full_response.strip()})
                    logger.info(f"💾 대화 히스토리 저장됨 (총 {len(_conversation_history)}개)")
                
                yield "data: [DONE]\n\n"

        except Exception as e:
            logger.error(f"LLM 스트리밍 오류: {e}")
            error_msg = clean_text_for_tts("네트워크 문제로 답변을 마무리하지 못했어요.")
            audio_b64 = await generate_tts_audio(error_msg)
            yield f"data: {json.dumps({'text': error_msg, 'audio': audio_b64})}\n\n"

# ---------------------------------------------------------
# 🔥 [API 엔드포인트 라우터] 플러터 앱이 POST로 보내는 데이터를 처리
# ---------------------------------------------------------
@app.post("/chat")
async def chat_endpoint(request: ChatRequest):
    # 플러터가 보낸 JSON 데이터를 풀어서 로그에 찍기
    logger.info(f"💌 사용자 메시지 수신: {request.user_message} (위치: {request.location}, 날씨: {request.weather_condition})")
    
    # 기상청 날씨(실데이터) 조회 - 캐싱됨. 실패해도 fallback 반환하므로 앱은 정상 동작
    # (KMA 호출은 blocking httpx이므로 이벤트 루프를 막지 않도록 to_thread 사용)
    weather_data = await asyncio.to_thread(weather_service.get_weather)
    
    # 스트리밍 응답 반환
    return StreamingResponse(
        stream_generator(request.user_message, request.location, weather_data),
        media_type="text/event-stream"
    )


# ---------------------------------------------------------
# [대화 히스토리 초기화] 옵션 엔드포인트 - 새 대화를 시작할 때 호출 (UI 변경 없음)
# ---------------------------------------------------------
@app.post("/chat/reset")
def reset_chat_history():
    cleared = len(_conversation_history)
    _conversation_history.clear()
    logger.info(f"🧹 대화 히스토리 초기화됨 ({cleared}개 제거)")
    return {"status": "ok", "cleared": cleared}

# ---------------------------------------------------------
# [날씨 조회 엔드포인트] 플러터 앱이 UI용 날씨를 요청 (→기상청)
# ---------------------------------------------------------
@app.get("/weather")
def get_weather(location_id: str = None):
    data = weather_service.get_weather(location_id)
    return data.to_dict()

# ---------------------------------------------------------
# [서버 실행]
# ---------------------------------------------------------
if __name__ == "__main__":
    import uvicorn
    logger.info(f"🚀 WeatherExer Backend 시작 중...")
    logger.info(f"   LLM:  {LLM_URL}")
    logger.info(f"   TTS:  {TTS_URL}")
    logger.info(f"   API:  http://{API_HOST}:{API_PORT}")
    uvicorn.run(app, host=API_HOST, port=API_PORT)