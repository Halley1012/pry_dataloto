param(
    [string]$DeviceId = '',
    [string]$ConfigPath = "$PSScriptRoot/config/rewards.dev.local.json",
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw 'Falta config/rewards.dev.local.json. Copia rewards.dev.example.json y configura el hash de prueba AdMob.'
}

$taskConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$taskConfig = Get-Content -LiteralPath $taskConfigPath -Raw | ConvertFrom-Json
if ($taskConfig.ENV -ne 'dev' -or
    "$($taskConfig.REWARDS_BACKEND_ENABLED)" -ine 'true' -or
    "$($taskConfig.ADS_USE_TEST_IDS)" -ine 'true') {
    throw 'La ejecución requiere ENV=dev, REWARDS_BACKEND_ENABLED=true y ADS_USE_TEST_IDS=true.'
}
if ($taskConfig.REWARDS_SSV_DEV_AD_UNIT_ID -notmatch '^ca-app-pub-\d{16}/\d{10}$' -or
    $taskConfig.REWARDS_SSV_DEV_AD_UNIT_ID.StartsWith('ca-app-pub-3940256099942544/')) {
    throw 'Configura un bloque recompensado propio para DEV, no el bloque compartido de demostración.'
}
$taskTestDevices = @("$($taskConfig.ADMOB_TEST_DEVICE_IDS)".Split(',') |
    ForEach-Object { $_.Trim() })
if ($taskTestDevices.Count -eq 0 -or
    @($taskTestDevices | Where-Object { $_ -notmatch '^[A-Fa-f0-9]{32}$' }).Count -gt 0) {
    throw 'ADMOB_TEST_DEVICE_IDS debe contener hashes AdMob válidos, separados por comas.'
}

Write-Host "DEV: créditos y pases; bloque $($taskConfig.REWARDS_SSV_DEV_AD_UNIT_ID)."
Write-Host "Dispositivos de prueba configurados: $($taskTestDevices.Count)."
if ($CheckOnly) { return }

$taskFlutterArgs = @('run', '--debug', "--dart-define-from-file=$taskConfigPath")
if ($DeviceId) { $taskFlutterArgs += @('-d', $DeviceId) }
Push-Location -LiteralPath $PSScriptRoot
try {
    & flutter @taskFlutterArgs
    if ($LASTEXITCODE -ne 0) { throw "Flutter terminó con código $LASTEXITCODE." }
} finally {
    Pop-Location
}
