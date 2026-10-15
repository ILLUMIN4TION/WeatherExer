"Stopping WheaterExer TTS(:9880) + FastAPI(:8000)..."
foreach ($port in @(9880, 8000)) {
  $c = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
  if ($c) {
    foreach ($pid2 in ($c | Select-Object -ExpandProperty OwningProcess -Unique)) {
      Stop-Process -Id $pid2 -Force -ErrorAction SilentlyContinue
      "  Stopped :$port (PID $pid2)"
    }
  } else {
    "  :$port not running"
  }
}
"Done. (LLM :8080 was NOT touched.)"