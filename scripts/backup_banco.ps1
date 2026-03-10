param(
  [string]$PastaBackup = ".\backups"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $PastaBackup)) {
  New-Item -ItemType Directory -Path $PastaBackup | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$arquivo = Join-Path $PastaBackup ("valeris_banco_" + $timestamp + ".sql")

docker exec valeris-postgres pg_dump -U valeris -d valeris > $arquivo

Write-Output "Backup criado: $arquivo"
