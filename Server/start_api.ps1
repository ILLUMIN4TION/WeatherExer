try { $host.UI.RawUI.WindowTitle = 'WheaterExer FastAPI :8000 (main.py)' } catch {}
# FastAPI middle server. MUST use the venv python (NOT system python).
Set-Location 'E:\WheaterExer_AI\Server'
# stdout/stderr를 UTF-8으로 강제: LLM이 한자/외국어 토큰을 섞어 출력해도
# print/로깅에서 cp949 UnicodeEncodeError가 나지 않도록 (TTS 스크립트와 동일)
$env:PYTHONUTF8 = "1"
# 로그 파일(E:\WheaterExer_AI\Server\server.log)은 main.py의 logging.FileHandler가
# Python 쪽에서 UTF-8으로 직접 기록 (파이프라인 오해석 방지). 콘솔 출력은 별도.
& 'E:\WheaterExer_AI\Server\venv\Scripts\python.exe' 'main.py'
"=== FastAPI exited (if you see this right away, check the errors above) ==="