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

# Адрес API стенда в туннеле Cloudflare — напрямую, без функции Cloudflare Pages:
# каждый запрос через Pages расходует платный лимит функций, а телефоны шлют трек
# каждые 2 минуты. Настоящий адрес телефона сервер берёт из X-Forwarded-For,
# который ставит Cloudflare (TRUST_PROXY), — ограничение попыток входа остаётся
# по каждому человеку.
$apiUrls = @{
  dev  = 'https://oxo-dev-api.saidolimxoja.uz'
  prod = 'https://oxo-api.saidolimxoja.uz'
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
  'app-arm64-v8a-release.apk'   = 'arm64'
  'app-armeabi-v7a-release.apk' = 'arm32'
}

# В имени файла — стенд и версия, чтобы сборки dev и prod разных версий не путались:
# HududNazorati-PROD-v1.2.2-arm64.apk
$versionName = $version.Split('+')[0]

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
    $out = Join-Path $outDir "HududNazorati-$($name.ToUpper())-v$versionName-$($apks[$apk]).apk"

    Copy-Item (Join-Path $built $apk) $out -Force
    Write-Output "Tayyor: $out"
  }

  # Карта R8 расшифровывает Android-часть стека в mobile_crash_reports (r8-map-id-…);
  # следующая сборка её перезапишет — храним рядом с картами Dart
  Copy-Item (Join-Path $PSScriptRoot 'build\app\outputs\mapping\release\mapping.txt') (Join-Path $symbols 'mapping.txt') -Force

  Write-Output "Belgilar xaritasi: $symbols"
}
