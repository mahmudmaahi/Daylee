#!/usr/bin/env bash
# Builds the release APK and copies it to dist/daylee-<version>+<build>.apk
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')
echo "Building DayLee $version ..."

flutter pub get
flutter analyze
flutter test
flutter build apk --release

mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk "dist/daylee-$version.apk"
echo "Done: dist/daylee-$version.apk"
