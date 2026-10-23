# Сборка APK мобильного приложения OXO.
# Адрес сервера задаётся при сборке, в коде его нет:
#   powershell -ExecutionPolicy Bypass -File build-apk.ps1 -ApiUrl https://oxo-api.example.uz
param(
  [Parameter(Mandatory)] [string]$ApiUrl
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=$ApiUrl

$apk = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
$out = Join-Path $PSScriptRoot 'OXO.apk'
Copy-Item $apk $out -Force
Write-Output "Tayyor: $out"
