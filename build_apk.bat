@echo off
flutter create --platforms=android .
if errorlevel 1 exit /b 1
flutter pub get
if errorlevel 1 exit /b 1
flutter build apk --release
if errorlevel 1 exit /b 1
echo APK: build\app\outputs\flutter-apk\app-release.apk
