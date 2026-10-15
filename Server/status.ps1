"WheaterExer server status:"
foreach ($port in @(9880, 8000, 8080)) {
  $c = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
  if ($c) { "  :$port LISTENING (PID " + (($c | Select-Object -ExpandProperty OwningProcess -Unique) -join ',') + ")" }
  else { "  :$port not listening" }
}
""
"LLM model check (should show the .gguf on :8080):"
$llm = Get-CimInstance Win32_Process -Filter "Name='llama-server.exe'" | Where-Object { $_.CommandLine -match 'port 8080' }
if ($llm) { foreach ($l in $llm) { "  PID $($l.ProcessId) : " + $l.CommandLine } } else { "  (no llama-server on 8080 found)" }