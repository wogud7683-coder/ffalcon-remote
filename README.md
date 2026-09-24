# FFALCON FF32S55 Remote

FFALCON FF32S55 / Android TV용 간단 리모컨 앱 프로젝트입니다.

## 포함 기능
- 같은 Wi‑Fi에서 Android TV 검색
- TV 연결
- Power
- 방향키 / OK
- Home / Back / Menu
- Volume + / - / Mute
- Channel + / -
- Input / Settings
- Play/Pause / Previous / Next / Rewind / Fast Forward
- Info / Guide
- 첫 연결 시 사용할 수 있는 pairing-code helper

## 기반
이 프로젝트는 `android_remote_pro` Flutter 패키지의 공개 API를 사용합니다.
해당 패키지는 Android TV 기기 검색, 연결, 키 이벤트 전송을 지원한다고 문서화되어 있습니다.

## 가장 쉬운 APK 빌드 방법
1. Flutter가 설치된 PC에서 이 폴더를 엽니다.
2. 아래 명령 실행:
   flutter create --platforms=android .
   flutter pub get
   flutter build apk --release
3. APK 위치:
   build/app/outputs/flutter-apk/app-release.apk

## GitHub Actions
`.github/workflows/build-apk.yml`도 포함되어 있습니다.
이 프로젝트를 GitHub 저장소에 올리면 Actions에서 release APK를 자동 빌드하도록 구성했습니다.

## 처음 연결할 때
- 휴대폰과 FF32S55가 반드시 같은 Wi‑Fi에 있어야 합니다.
- 앱에서 TV를 검색하고 연결합니다.
- TV에 페어링 코드가 뜨면 우측 상단 PIN 버튼을 사용할 수 있습니다.
- Android TV Remote Service 구현 차이에 따라 pairing이 자동 처리될 수도 있습니다.

## 주의
실제 FF32S55 기기에서의 최종 동작 검증은 물리 TV가 필요합니다.
특히 최초 pairing 흐름은 TV의 Android TV Remote Service 버전에 따라 차이가 있을 수 있습니다.
