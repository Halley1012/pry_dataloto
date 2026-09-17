$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

Write-Host "Eterlotto ML - migracion local a DEV/PRD" -ForegroundColor Cyan

# 1. Migrar el .env legado sin mostrar secretos.
if ((Test-Path ".env") -and -not (Test-Path ".env.dev")) {
    Move-Item ".env" ".env.dev"
    Write-Host "OK: .env -> .env.dev"
} elseif ((Test-Path ".env") -and (Test-Path ".env.dev")) {
    Write-Host "AVISO: existen .env y .env.dev; no se sobrescribio ninguno." -ForegroundColor Yellow
}

if (-not (Test-Path ".env.dev")) {
    Copy-Item ".env.dev.example" ".env.dev"
    Write-Host "AVISO: se creo .env.dev desde la plantilla. Completa las credenciales DEV." -ForegroundColor Yellow
}

function Add-EnvIfMissing([string]$Name, [string]$Value) {
    $content = Get-Content ".env.dev" -Raw
    if ($content -notmatch "(?m)^$([regex]::Escape($Name))=") {
        Add-Content ".env.dev" "`n$Name=$Value"
    }
}

Add-EnvIfMissing "APP_ENV" "dev"
Add-EnvIfMissing "SMTP_ENABLED" "true"
Add-EnvIfMissing "SMTP_HOST" "smtp.gmail.com"
Add-EnvIfMissing "SMTP_PORT" "587"
Add-EnvIfMissing "SMTP_STARTTLS" "true"
Add-EnvIfMissing "SMTP_USER" ""
Add-EnvIfMissing "SMTP_PASSWORD" ""
Add-EnvIfMissing "SMTP_FROM" ""
Add-EnvIfMissing "SMTP_TO" ""
Add-EnvIfMissing "FIREBASE_CREDENTIALS_FILE" ".secrets/firebase_credentials.json"

# 2. Mover credencial Firebase local a carpeta ignorada por Git.
if (-not (Test-Path ".secrets")) {
    New-Item -ItemType Directory ".secrets" | Out-Null
}

if ((Test-Path "config/firebase_credentials.json") -and -not (Test-Path ".secrets/firebase_credentials.json")) {
    Move-Item "config/firebase_credentials.json" ".secrets/firebase_credentials.json"
    Write-Host "OK: Firebase movido a .secrets/firebase_credentials.json"
} elseif ((Test-Path "config/firebase_credentials.json") -and (Test-Path ".secrets/firebase_credentials.json")) {
    Write-Host "AVISO: hay dos credenciales Firebase; revisalas antes de borrar una." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Migracion DEV completada." -ForegroundColor Green
Write-Host "1) Completa SMTP_USER/SMTP_PASSWORD con una credencial NUEVA si quieres alertas."
Write-Host "2) Verifica que .env.dev apunte a db-eterlotto-dev."
Write-Host "3) Ejecuta: python -m pytest -q tests/test_settings.py tests/test_environment_hygiene.py"
Write-Host "4) Revisa DEV_PRD.md antes de crear PRD."
