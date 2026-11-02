# Сборка APK мобильного приложения «Ҳудуд назорати».
# Адрес сервера задаётся при сборке, в коде его нет:
#   powershell -ExecutionPolicy Bypass -File build-apk.ps1 -ApiUrl https://oxo-api.example.uz
# Получаются два файла: arm64 — почти все телефоны, arm32 — старые 32-битные.
# Нужен ключ подписи android/key.properties (см. README, «Ключ подписи»).
param(
  [Parameter(Mandatory)] [string]$ApiUrl
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# Токены и селфи идут по сети — только https
if ($ApiUrl -notmatch '^https://') {
  throw "Адрес сервера должен начинаться с https:// (получено: $ApiUrl)"
}

# Отладочный ключ общий для всех Flutter-проектов: подписанное им обновление
# мог бы выпустить кто угодно
if (-not (Test-Path (Join-Path $PSScriptRoot 'android\key.properties'))) {
  throw 'Нет android\key.properties — release подписывается только своим ключом (см. README, «Ключ подписи»).'
}

# Карты символов для расшифровки отчётов о падениях остаются на машине сборки,
# у каждой версии свои (стек из mobile_crash_reports читается только картами той же
# сборки). Папка symbols не в git и не чистится `flutter clean` — её надо хранить.
$version = (Select-String -Path (Join-Path $PSScriptRoot 'pubspec.yaml') -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$symbols = Join-Path $PSScriptRoot "symbols\$version"

flutter pub get
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64 `
  --obfuscate --split-debug-info=$symbols `
  --dart-define=API_BASE_URL=$ApiUrl

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

Write-Output "Belgilar xaritasi: $symbols"
