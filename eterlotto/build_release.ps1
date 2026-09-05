$pubspecPath = "pubspec.yaml"
$content = Get-Content $pubspecPath
$newContent = @()

foreach ($line in $content) {
    if ($line -match "^version:\s*(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)\+(?<build>\d+)") {
        $major = $matches['major']
        $minor = $matches['minor']
        $patch = $matches['patch']
        $build = [int]$matches['build'] + 1
        
        $newVersion = "version: $major.$minor.$patch+$build"
        Write-Host "✅ Bumped version from $($line.Substring(9)) to $major.$minor.$patch+$build" -ForegroundColor Green
        $newContent += $newVersion
    } else {
        $newContent += $line
    }
}

$newContent | Set-Content $pubspecPath
Write-Host "🚀 Iniciando build (flutter build appbundle --release)..." -ForegroundColor Cyan
flutter build appbundle --release
Write-Host "🎉 Build completado. El AAB está listo." -ForegroundColor Green
