try { $host.UI.RawUI.WindowTitle = 'WheaterExer TTS :9880 (api_v2.py)' } catch {}
# GPT-SoVITS TTS server (nahida voice). MUST set PYTHONUTF8=1 to avoid cp949 UnicodeEncodeError.
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'
Set-Location 'E:\WheaterExer_AI\TTS'
# Use the bundled runtime python (has correct deps). Do NOT use run_api.bat (it runs old api.py).
& 'E:\WheaterExer_AI\TTS\runtime\python.exe' 'api_v2.py' -a 127.0.0.1 -p 9880 -c 'GPT_SoVITS/configs/tts_infer.yaml'
"=== TTS exited (if you see this right away, check the errors above) ==="