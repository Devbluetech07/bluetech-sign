# Script de validação dos microsserviços e upload no MinIO

# Pixel PNG válido (1x1) em base64
$pixel = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI6QAAAABJRU5ErkJggg=="

$servicos = @("assinatura", "documento", "documento", "selfie", "selfie-documento")
$baseUrl = "http://localhost:3001/api"
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$emailTeste = "teste.captura.$timestamp@valeris.local"
$senhaTeste = "SenhaSegura123"

# Cria usuário de teste e obtém JWT válido para o novo modelo de autenticação.
Invoke-RestMethod -Uri "$baseUrl/auth/register" -Method POST -ContentType "application/json" -Body (@{
    email = $emailTeste
    password = $senhaTeste
    nome_completo = "Usuário Teste Captura"
} | ConvertTo-Json) | Out-Null

$login = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{
    email = $emailTeste
    password = $senhaTeste
} | ConvertTo-Json)

$jwt = $login.token

foreach ($servico in $servicos) {
    $payload = @{
        service_type = $servico
        image_data   = $pixel
        metadata     = @{
            latitude            = -23.5505
            longitude           = -46.6333
            endereco            = "Rua Teste, 123 - São Paulo, SP"
            ip                  = "192.168.1.1"
            user_agent          = "TestAgent/1.0"
            navegador           = "TestBrowser"
            sistema_operacional = "Windows"
            plataforma          = "Win32"
            idioma              = "pt-BR"
            resolucao_tela      = "1920x1080"
            serviceType         = $servico
        }
    } | ConvertTo-Json -Depth 5

    Write-Host "`n=== Testando [$servico] ===" -ForegroundColor Cyan
    try {
        $resp = Invoke-RestMethod -Uri "$baseUrl/captures/" -Method POST `
            -ContentType "application/json" -Body $payload -Headers @{Authorization="Bearer $jwt"} -ErrorAction Stop
        Write-Host "✅ SUCESSO" -ForegroundColor Green
        Write-Host "   ID:          $($resp.id)"
        Write-Host "   Serviço:     $($resp.service_type)"
        Write-Host "   Status:      $($resp.status)"
        Write-Host "   Arquivo:     $($resp.image_data)"
    } catch {
        Write-Host "❌ ERRO: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ErrorDetails.Message) {
            Write-Host "   Detalhe: $($_.ErrorDetails.Message)" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n=== Verificação MinIO ===" -ForegroundColor Cyan
Write-Host "Acesse: http://localhost:29001"
Write-Host "Bucket: bluetech-sign"
Write-Host "Pastas: assinatura/, documento/, selfie/, selfie-documento/"
