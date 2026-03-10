param(
  [Parameter(Mandatory = $true)]
  [string]$ArquivoBackup
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $ArquivoBackup)) {
  throw "Arquivo não encontrado: $ArquivoBackup"
}

Get-Content $ArquivoBackup | docker exec -i valeris-postgres psql -U valeris -d valeris

Write-Output "Restauração concluída com sucesso."
