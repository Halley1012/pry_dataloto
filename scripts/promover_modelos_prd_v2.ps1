param(
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

$Source = "D:\pry_dataloto\modelos_ML"
$Destination = "D:\pry_eterlotto_prd\modelos_ML"
$BackupRoot = "D:\pry_eterlotto_prd"

$ExcludedFiles = @(
    ".env",
    ".env.*",
    "*.pyc"
)

$ExcludedDirs = @(
    ".secrets",
    "scratch",
    "_cache_patch_backups",
    "__pycache__",
    ".pytest_cache"
)

if (-not (Test-Path $Source)) {
    throw "No existe la carpeta DEV: $Source"
}
if (-not (Test-Path $Destination)) {
    throw "No existe la carpeta PRD: $Destination"
}

$CommonArgs = @(
    $Source,
    $Destination,
    "/MIR",
    "/FP",
    "/NP",
    "/R:2",
    "/W:2",
    "/XF"
) + $ExcludedFiles + @(
    "/XD"
) + $ExcludedDirs

Write-Host ""
Write-Host "==============================================="
Write-Host " ETERLOTTO - PROMOCION modelos_ML DEV -> PRD"
Write-Host "==============================================="
Write-Host "DEV: $Source"
Write-Host "PRD: $Destination"
Write-Host ""

if (-not $Apply) {
    Write-Host "MODO PREVIEW: no se modificara PRD."
    Write-Host ""

    & robocopy @CommonArgs "/L"
    $code = $LASTEXITCODE

    Write-Host ""
    if ($code -le 7) {
        Write-Host "Preview finalizado correctamente. Robocopy exit code: $code"
        Write-Host "Para aplicar:"
        Write-Host "  .\promover_modelos_prd_v2.ps1 -Apply"
        exit 0
    }

    throw "Robocopy fallo en preview. Exit code: $code"
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Backup = Join-Path $BackupRoot "modelos_ML_backup_$timestamp"

Write-Host "MODO APPLY"
Write-Host "Backup previo: $Backup"
Write-Host ""

Copy-Item $Destination $Backup -Recurse -Force

if (-not (Test-Path $Backup)) {
    throw "No fue posible crear el backup de PRD."
}

Write-Host "Backup creado correctamente."
Write-Host "Sincronizando DEV -> PRD..."
Write-Host ""

& robocopy @CommonArgs
$code = $LASTEXITCODE

if ($code -gt 7) {
    throw "Robocopy fallo. Exit code: $code. Backup: $Backup"
}

Write-Host ""
Write-Host "Sincronizacion terminada correctamente."
Write-Host "Robocopy exit code: $code"
Write-Host ""
Write-Host "Protegidos:"
Write-Host "  .env / .env.*"
Write-Host "  .secrets"
Write-Host "  scratch"
Write-Host "  _cache_patch_backups"
Write-Host "  __pycache__"
Write-Host "  .pytest_cache"
Write-Host ""
Write-Host "Backup: $Backup"
