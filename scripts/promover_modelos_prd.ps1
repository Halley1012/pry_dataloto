param(
    [string]$Source = "D:\pry_dataloto\modelos_ML",
    [string]$Destination = "D:\pry_eterlotto_prd\modelos_ML",
    [switch]$Apply,
    [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"

function Write-Step($Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Path($PathValue, $Label) {
    if (-not (Test-Path -LiteralPath $PathValue)) {
        throw "$Label no existe: $PathValue"
    }
}

Write-Host "Eterlotto - Promocion modelos_ML DEV -> PRD" -ForegroundColor Yellow
Write-Host "DEV: $Source"
Write-Host "PRD: $Destination"

Assert-Path $Source "La carpeta DEV"

if (-not (Test-Path -LiteralPath $Destination)) {
    if ($Apply) {
        Write-Step "Creando carpeta PRD"
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    } else {
        Write-Host ""
        Write-Host "[PREVIEW] La carpeta PRD no existe y se crearia al usar -Apply." -ForegroundColor DarkYellow
    }
}

if (-not $SkipCompile) {
    Write-Step "Validando sintaxis Python en DEV"

    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        throw "No se encontro 'python' en PATH. Instala Python o ejecuta con -SkipCompile."
    }

    & python -m compileall -q $Source
    if ($LASTEXITCODE -ne 0) {
        throw "La validacion Python fallo. No se promocionara nada a PRD."
    }

    Write-Host "Sintaxis Python OK." -ForegroundColor Green
}

$excludeDirs = @(
    ".git",
    ".venv",
    "venv",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    "_cache_patch_backups",
    "logs"
)

$excludeFiles = @(
    ".env",
    ".env.*",
    "firebase_credentials.json",
    "service-account*.json",
    "service_account*.json",
    "credentials*.json",
    "*.pem",
    "*.key",
    "*.log",
    "*.pyc"
)

$commonArgs = @(
    $Source,
    $Destination,
    "/MIR",
    "/FFT",
    "/R:2",
    "/W:2",
    "/COPY:DAT",
    "/DCOPY:DAT",
    "/NP",
    "/NDL",
    "/NFL",
    "/XJ"
)

foreach ($dir in $excludeDirs) {
    $commonArgs += "/XD"
    $commonArgs += $dir
}

foreach ($file in $excludeFiles) {
    $commonArgs += "/XF"
    $commonArgs += $file
}

if (-not $Apply) {
    Write-Step "PREVIEW - no se modificara PRD"
    Write-Host "Se mostraran altas, cambios y eliminaciones que haria la sincronizacion." -ForegroundColor DarkYellow

    $previewArgs = @($commonArgs)
    $previewArgs += "/L"
    $previewArgs += "/V"

    & robocopy @previewArgs
    $rc = $LASTEXITCODE

    if ($rc -ge 8) {
        throw "Robocopy reporto un error en preview. Codigo: $rc"
    }

    Write-Host ""
    Write-Host "PREVIEW terminado. No se modifico PRD." -ForegroundColor Green
    Write-Host "Si todo se ve bien, ejecuta:" -ForegroundColor Yellow
    Write-Host "  .\promover_modelos_prd.ps1 -Apply"
    exit 0
}

Write-Step "Creando respaldo rapido de PRD"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupRoot = Join-Path (Split-Path $Destination -Parent) "_promociones_backup"
$backupPath = Join-Path $backupRoot ("modelos_ML_" + $timestamp)

if (Test-Path -LiteralPath $Destination) {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

    $backupArgs = @(
        $Destination,
        $backupPath,
        "/E",
        "/FFT",
        "/R:1",
        "/W:1",
        "/COPY:DAT",
        "/DCOPY:DAT",
        "/NP",
        "/NDL",
        "/NFL",
        "/XJ"
    )

    & robocopy @backupArgs
    $backupRc = $LASTEXITCODE
    if ($backupRc -ge 8) {
        throw "No se pudo crear el respaldo de PRD. Codigo Robocopy: $backupRc"
    }

    Write-Host "Backup: $backupPath" -ForegroundColor Green
}

Write-Step "Sincronizando codigo aprobado DEV -> PRD"
& robocopy @commonArgs
$rc = $LASTEXITCODE

if ($rc -ge 8) {
    throw "Robocopy fallo. Codigo: $rc"
}

Write-Step "Validando que secretos DEV no hayan sido copiados"

$forbidden = @(
    (Join-Path $Destination ".env"),
    (Join-Path $Destination ".env.dev"),
    (Join-Path $Destination "config\firebase_credentials.json")
)

$foundForbidden = @()
foreach ($item in $forbidden) {
    if (Test-Path -LiteralPath $item) {
        $foundForbidden += $item
    }
}

if ($foundForbidden.Count -gt 0) {
    Write-Host "ATENCION: estos archivos existen en PRD:" -ForegroundColor Red
    $foundForbidden | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host "No fueron necesariamente copiados por este script; revisalos antes de levantar PRD." -ForegroundColor Yellow
} else {
    Write-Host "No se detectaron secretos DEV en los nombres verificados." -ForegroundColor Green
}

Write-Host ""
Write-Host "Promocion completada." -ForegroundColor Green
Write-Host "Siguiente paso recomendado: levantar Airflow PRD y ejecutar 'airflow dags list-import-errors'."
