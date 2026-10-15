# ============================================================
# WheaterExer /chat E2E test (Qwen -> TTS -> SSE -> WAV)
# Usage:
#   powershell -ExecutionPolicy Bypass -File e2e_test.ps1
#
# Note: ASCII-only on purpose so it runs under any Windows
# console code page (cp949/cp936/UTF-8 all fine).
# The LLM system prompt forces a Korean reply even though the
# test message below is English.
#
# Expected when a NON-reasoning model (Qwen2.5) is on :8080:
#   1 or more chunks, each with non-empty text + audio,
#   every audio chunk decodes to a valid RIFF/WAVE,
#   stream ends with data: [DONE]  =>  E2E RESULT: PASS
#
# If Qwen3.8 (reasoning model) is on :8080, expect:
#   0 chunks, only [DONE]  =>  E2E RESULT: FAIL
#   (all tokens go to reasoning_content, content is empty)
# ============================================================

$ErrorActionPreference = 'Stop'

$uri   = 'http://127.0.0.1:8000/chat'
$body  = '{"user_message":"What is the weather like in Seoul today?","location":"Seoul","weather_condition":"clear"}'
$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)

Write-Host '>> POST /chat ...'
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$r = Invoke-WebRequest -UseBasicParsing -Uri $uri -Method Post `
      -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 300
$sw.Stop()
Write-Host (">> HTTP " + $r.StatusCode + " in " + [math]::Round($sw.Elapsed.TotalSeconds,1) + "s, body " + $r.Content.Length + " bytes")

$out = Join-Path $env:TEMP 'wheatexer_chat_sse.txt'
Set-Content -Path $out -Value $r.Content -Encoding UTF8
Write-Host (">> raw SSE saved to: " + $out)

$lines = $r.Content -split "`n" | Where-Object { $_ -match '^data: \{' }
Write-Host (">> text/audio chunks: " + $lines.Count)

$ok = $true
$i = 0
foreach ($l in $lines) {
    $j = ($l -replace '^data: ','') | ConvertFrom-Json
    $i++
    if (-not $j.text)  { Write-Host ("   chunk " + $i + " EMPTY TEXT");  $ok = $false }
    if (-not $j.audio) { Write-Host ("   chunk " + $i + " EMPTY AUDIO"); $ok = $false }

    if ($j.audio) {
        $ab = [Convert]::FromBase64String($j.audio)
        $wavPath = Join-Path $env:TEMP ("wheatexer_chunk_" + $i + ".wav")
        [IO.File]::WriteAllBytes($wavPath, $ab)
        $riff = [System.Text.Encoding]::ASCII.GetString($ab, 0, 4)
        $wave = [System.Text.Encoding]::ASCII.GetString($ab, 8, 4)
        Write-Host ("   chunk " + $i + " text=[" + $j.text + "] wav=" + $ab.Length + "B header=" + $riff + $wave + " file=" + $wavPath)
        if ($riff -ne 'RIFF' -or $wave -ne 'WAVE') {
            Write-Host '   !! NOT A VALID WAV HEADER'
            $ok = $false
        }
    } else {
        Write-Host ("   chunk " + $i + " text=[" + $j.text + "] (no audio)")
    }
}

if ($r.Content -notmatch 'data: \[DONE\]') {
    Write-Host '>> WARNING: stream did not end with data: [DONE]'
    $ok = $false
}

if ($ok -and $lines.Count -gt 0) {
    Write-Host '>> E2E RESULT: PASS (text + audio + valid WAV + DONE all present)'
} else {
    Write-Host '>> E2E RESULT: FAIL (see above; if 0 chunks, check which model is loaded on :8080)'
}
