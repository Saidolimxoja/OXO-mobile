# Сборка APK мобильного приложения «Ҳудуд назорати» для обоих стендов:
#   powershell -ExecutionPolicy Bypass -File build-apk.ps1               # dev и prod
#   powershell -ExecutionPolicy Bypass -File build-apk.ps1 -Stand prod   # только один
# Готовые файлы — в папке стенда (dev\, prod\): arm64 — почти все телефоны,
# arm32 — старые 32-битные. Адрес сервера зашивается при сборке, в коде его нет.
# Нужен ключ подписи android/key.properties (см. README, «Ключ подписи»).
param(
  [ValidateSet('dev', 'prod')] [string[]]$Stand = @('dev', 'prod')
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# Сайт стенда: его /api проксирует Cloudflare Pages на бэкенд и передаёт настоящий
# адрес телефона (ограничение попыток входа считается по каждому человеку)
$apiUrls = @{
  dev  = 'https://oxo-dev.saidolimxoja.uz'
  prod = 'https://oxo.saidolimxoja.uz'
}

# Отладочный ключ общий для всех Flutter-проектов: подписанное им обновление
# мог бы выпустить кто угодно
if (-not (Test-Path (Join-Path $PSScriptRoot 'android\key.properties'))) {
  throw 'Нет android\key.properties — release подписывается только своим ключом (см. README, «Ключ подписи»).'
}

# Карты символов для расшифровки отчётов о падениях остаются на машине сборки,
# у каждой сборки свои (стек из mobile_crash_reports читается только картами той же
# сборки). Папка symbols не в git и не чистится `flutter clean` — её надо хранить.
$version = (Select-String -Path (Join-Path $PSScriptRoot 'pubspec.yaml') -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$built = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk'
$apks = @{
  'app-arm64-v8a-release.apk'   = 'HududNazorati-arm64.apk'
  'app-armeabi-v7a-release.apk' = 'HududNazorati-arm32.apk'
}

flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get завершился с ошибкой' }

foreach ($name in $Stand) {
  $apiUrl = $apiUrls[$name]
  $outDir = Join-Path $PSScriptRoot $name
  $symbols = Join-Path $PSScriptRoot "symbols\$version\$name"

  Write-Output "=== $name : $apiUrl"

  flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64 `
    --obfuscate --split-debug-info=$symbols `
    --dart-define=API_BASE_URL=$apiUrl
  if ($LASTEXITCODE -ne 0) { throw "Сборка $name завершилась с ошибкой" }

  New-Item -ItemType Directory -Force $outDir | Out-Null

  # Следующая сборка перезапишет build\ — копируем сразу
  foreach ($apk in $apks.Keys) {
    $out = Join-Path $outDir $apks[$apk]

    Copy-Item (Join-Path $built $apk) $out -Force
    Write-Output "Tayyor: $out"
  }

  Write-Output "Belgilar xaritasi: $symbols"
}
