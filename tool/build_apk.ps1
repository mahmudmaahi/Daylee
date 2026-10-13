# Builds the release APK and copies it to dist\daylee-<version>+<build>.apk
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$version = ((Select-String -Path pubspec.yaml -Pattern '^version:').Line -split '\s+')[1]
Write-Host "Building DayLee $version ..."

flutter pub get;            if ($LASTEXITCODE) { exit $LASTEXITCODE }
flutter analyze;            if ($LASTEXITCODE) { exit $LASTEXITCODE }
flutter test;               if ($LASTEXITCODE) { exit $LASTEXITCODE }
flutter build apk --release; if ($LASTEXITCODE) { exit $LASTEXITCODE }

New-Item -ItemType Directory -Force dist | Out-Null
Copy-Item build\app\outputs\flutter-apk\app-release.apk "dist\daylee-$version.apk" -Force
Write-Host "Done: dist\daylee-$version.apk"
