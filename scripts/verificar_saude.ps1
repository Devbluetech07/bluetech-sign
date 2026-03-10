$ErrorActionPreference = "Stop"

$saudeApi = Invoke-RestMethod -Uri "http://localhost:3001/health" -Method GET
$saudeEmbeddings = Invoke-RestMethod -Uri "http://localhost:3001/health/embeddings" -Method GET

Write-Output ("API: " + ($saudeApi | ConvertTo-Json -Compress))
Write-Output ("Embeddings: " + ($saudeEmbeddings | ConvertTo-Json -Compress))
