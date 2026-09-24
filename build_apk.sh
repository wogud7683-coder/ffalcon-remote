#!/usr/bin/env bash
set -e
flutter create --platforms=android .
flutter pub get
flutter build apk --release
echo "APK: build/app/outputs/flutter-apk/app-release.apk"
