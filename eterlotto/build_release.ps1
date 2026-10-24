param(
    [string]$ConfigPath = "$PSScriptRoot/config/rewards.prd.json",
    [int]$BuildNumber = 0,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
$taskConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$taskConfig = Get-Content -LiteralPath $taskConfigPath -Raw | ConvertFrom-Json
if ($taskConfig.ENV -cne 'prd' -or
    "$($taskConfig.REWARDS_BACKEND_ENABLED)" -ine 'true' -or
    "$($taskConfig.ADS_USE_TEST_IDS)" -ine 'false') {
    throw 'Release requiere ENV=prd, REWARDS_BACKEND_ENABLED=true y ADS_USE_TEST_IDS=false.'
}
if (-not [string]::IsNullOrWhiteSpace($taskConfig.REWARDS_SSV_DEV_AD_UNIT_ID) -or
    -not [string]::IsNullOrWhiteSpace($taskConfig.ADMOB_TEST_DEVICE_IDS) -or
    "$($taskConfig.UMP_DEBUG_EEA)" -ieq 'true' -or
    "$($taskConfig.UMP_RESET_CONSENT)" -ieq 'true') {
    throw 'Retira bloques DEV, dispositivos de prueba y depuración UMP de la configuración PRD.'
}

$taskPubspecPath = Join-Path $PSScriptRoot 'pubspec.yaml'
$taskContent = Get-Content -LiteralPath $taskPubspecPath -Raw
$taskVersionMatch = [regex]::Match($taskContent, '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)[ \t\r]*$')
if (-not $taskVersionMatch.Success) { throw 'No se encontró version: x.y.z+build en pubspec.yaml.' }
$taskCurrentBuild = [int]$taskVersionMatch.Groups[2].Value
$taskNextBuild = if ($BuildNumber -gt 0) { $BuildNumber } else { $taskCurrentBuild + 1 }
if ($taskNextBuild -le $taskCurrentBuild) { throw 'El nuevo build debe superar el build de pubspec.yaml.' }

Write-Host "PRD: https://eterlotto-api-prd.onrender.com; créditos y pases; AdMob 4124989907."
Write-Host "Build Android: $taskNextBuild. Verifica que también supere el último publicado en Play Console."
if ($CheckOnly) { return }

Push-Location -LiteralPath $PSScriptRoot
try {
    & flutter build appbundle --release "--build-number=$taskNextBuild" "--dart-define-from-file=$taskConfigPath"
    if ($LASTEXITCODE -ne 0) { throw "Flutter terminó con código $LASTEXITCODE. El AAB no está listo." }
    $taskNewVersion = "version: $($taskVersionMatch.Groups[1].Value)+$taskNextBuild"
    $taskNewContent = $taskContent.Replace($taskVersionMatch.Value.TrimEnd(), $taskNewVersion)
    Set-Content -LiteralPath $taskPubspecPath -Value $taskNewContent -NoNewline -Encoding utf8
    Write-Host 'AAB generado: build/app/outputs/bundle/release/app-release.aab'
} finally {
    Pop-Location
}
