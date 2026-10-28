# Сборка APK мобильного приложения «Ҳудуд назорати».
# Адрес сервера задаётся при сборке, в коде его нет:
#   powershell -ExecutionPolicy Bypass -File build-apk.ps1 -ApiUrl https://oxo-api.example.uz
# Получаются два файла: arm64 — почти все телефоны, arm32 — старые 32-битные.
param(
  [Parameter(Mandatory)] [string]$ApiUrl
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

flutter pub get
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64 --dart-define=API_BASE_URL=$ApiUrl

$built = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk'
$apks = @{
  'app-arm64-v8a-release.apk'   = 'HududNazorati-arm64.apk'
  'app-armeabi-v7a-release.apk' = 'HududNazorati-arm32.apk'
}

foreach ($name in $apks.Keys) {
  $out = Join-Path $PSScriptRoot $apks[$name]

  Copy-Item (Join-Path $built $name) $out -Force
  Write-Output "Tayyor: $out"
}
