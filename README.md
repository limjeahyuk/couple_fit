# Couple Fit

연인과 함께 쓰는 운동 앱. 루틴을 만들고, 세트·휴식 타이머로 운동하고, 짝꿍의 운동과 몸 변화를 함께 보고 비교합니다.

Flutter (iOS / Android) + Firebase (Auth · Firestore · Hosting, 선택: Cloud Functions · FCM)

## 주요 기능

| 영역 | 내용 |
|---|---|
| **홈** | 오늘의 추천 루틴 · 운동 시작, 운동 중 카드(경과 시간 · 현재 세트/휴식), 오늘 우리 둘 완료 여부 · 함께 N일 연속, 이번 주 기록, 콕 찌르기 |
| **운동** | 루틴 목록 · 편집, 짝꿍 루틴 짜주기. 운동 중에도 하단 탭 이동 가능 |
| **운동 진행** | 세트 완료 → 휴식 카운트다운(+15초 · 건너뛰기), 횟수·무게를 숫자 탭 → ▲▼로 수정, 세트별 기록 저장, 끝나면 바꾼 값을 루틴에 저장 |
| **캘린더** | 두 사람의 월간 운동 기록, 날짜별 세트 상세 |
| **기록** | 몸 기록(키 · 체중 · 체지방률 · 골격근량 → 체지방량 · BMI 자동 계산), 변화 그래프(실제 값 / 처음 대비 변화, 짝꿍 겹쳐 보기), 짝꿍과 비교, 운동 기록(함께 · 나 · 짝꿍) |
| **커플** | 초대 링크 / 커플 코드로 연결, 아바타 꾸미기(배경색 · 캐릭터) |
| **로그인** | Apple · Google · 이메일 |
| **iOS 잠금화면** | 운동 중 Live Activity / 다이내믹 아일랜드(경과 시간 · 휴식 카운트다운), 휴식 끝 알림 |

짝꿍의 **오늘** 기록은 내가 오늘 운동을 끝내야 보입니다(서로 동기부여용 잠금).

## 시작하기

### 1. 준비물
- Flutter (stable), Xcode, CocoaPods, Firebase CLI (`npm i -g firebase-tools`), FlutterFire CLI (`dart pub global activate flutterfire_cli`)
- Homebrew rsync — iOS 빌드에 필요 (아래 [iOS 빌드 참고](#ios-빌드-참고))
  ```bash
  brew install rsync
  ```

### 2. Firebase 연결
Firebase 설정 파일은 API 키가 들어 있어 저장소에서 제외되어 있습니다(`.gitignore`). 처음 받았다면 직접 생성하세요.

```bash
firebase login
flutterfire configure --project=<프로젝트 ID> --platforms=android,ios
```
→ `lib/firebase_options.dart`, `ios/Runner/GoogleService-Info.plist`, `android/app/google-services.json`이 생깁니다.

> `firebase.json`이 이미 있어 "reuse the values?"를 물으면 **no**를 고르세요.
> 맥 기본 Ruby에 `xcodeproj`가 없어 실패하면 CocoaPods의 Ruby로 실행합니다:
> `PATH="/opt/homebrew/opt/ruby/bin:$PATH" GEM_HOME="$(brew --prefix cocoapods)/libexec" flutterfire configure ...`

Firebase 콘솔에서 켤 것:
- **Authentication** › 로그인 방법: 이메일/비밀번호, Google, Apple
- **Firestore Database** (위치: `asia-northeast3` 권장)
- **Hosting** (초대 링크 페이지)

다른 Firebase 프로젝트를 쓰면 바꿔야 하는 값:
- `lib/invite.dart`의 `inviteHost`, `ios/Runner/Runner.entitlements`, `android/app/src/main/AndroidManifest.xml` 의 `couplefit-a47ae.web.app`
- `lib/auth.dart`의 `_googleWebClientId` (google-services.json의 `client_type: 3`)
- `ios/Runner/Info.plist`의 Google URL scheme (GoogleService-Info.plist의 `REVERSED_CLIENT_ID`)

### 3. 배포 (보안 규칙 · 초대 페이지)
```bash
firebase deploy --only firestore:rules,hosting
```
Blaze 요금제라면 푸시용 Cloud Functions까지:
```bash
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,hosting,functions
```

### 4. 실행
```bash
flutter pub get
open ios/Runner.xcworkspace   # Xcode에서 ▶︎ (권장)
# 또는
flutter run
```

## 프로젝트 구조

```
lib/
  main.dart        앱 시작, 로그인 화면, 탭 셸(Firestore 실시간 구독 → AppData)
  db.dart          Firestore 경로 · 모델, AppData(잠금/연속일/추천 루틴), 몸 지표 계산, 기본 루틴
  theme.dart       디자인 토큰(색 · 폰트), 공용 위젯(avatar, box, ring, bar ...)
  home.dart        홈
  routines.dart    루틴 목록 · 편집, 짝꿍 루틴
  workout.dart     WorkoutTracker(순수 로직) · WorkoutSession(탭 위에서 유지) · 운동/완료 화면
  calendar.dart    캘린더
  records.dart     기록 탭(몸 기록 · 그래프 · 비교 · 운동 기록), 측정 입력
  couple.dart      커플 연결, 아바타 꾸미기
  auth.dart        Google / Apple 로그인, 첫 로그인 시 프로필 생성
  invite.dart      초대 링크(생성 · 공유 · 열기 · 자동 연결)
  push.dart        FCM 토큰 등록, Android 포그라운드 알림
  demo.dart        개발용 데모 짝꿍(메모리에만 존재)
ios/
  Shared/WorkoutAttributes.swift     Live Activity 모델(앱 · 위젯 공용)
  Runner/WorkoutLiveActivity.swift   MethodChannel: 잠금화면 타이머 시작/갱신/종료, 휴식 끝 알림
  WorkoutWidget/                     잠금화면 · 다이내믹 아일랜드 위젯 (iOS 16.2+)
  tools/rsync                        iOS 빌드용 rsync 래퍼 (아래 참고)
functions/         Cloud Functions: 운동 완료 · 콕 찌르기 · 연결 요청 푸시, 초대 링크 자동 연결
hosting/public/    초대 링크 안내 페이지, Universal Link / App Link 확인 파일
firestore.rules    보안 규칙
test/              로직 테스트 + 화면 렌더(오버플로) 테스트
```

### 데이터 (Firestore)
```
users/{uid}                {name, code, partnerId?, nudgeAt?, avatar?}
users/{uid}/routines/*     {name, tag, exercises[], by, createdAt, lastDone?}
users/{uid}/sessions/*     {date, routine, totalSec, restSec, sets, exCount, notify, log[], endedAt}
users/{uid}/body/{date}    {date, height, weight, fat, muscle?}
users/{uid}/private/*      fcm 토큰, 초대 토큰 (본인만)
```
두 사람이 서로의 `partnerId`를 가리킬 때만 연결된 것으로 보고, 그때만 서로의 루틴 · 운동 · 몸 기록을 읽을 수 있습니다(`firestore.rules`).

## 짝꿍 연결 · 초대 링크
- 커플 화면 › **초대 링크 보내기** → `https://<host>/invite/<코드>?t=<1회용 토큰>`
- 받은 사람이 누르면 앱이 열리고 확인 후 **수락 없이 바로 연결** (앱이 없으면 안내 페이지)
- 토큰은 보낸 사람만 읽을 수 있는 곳에 저장되고 한 번 쓰면 사라집니다. Blaze 없이도 보낸 사람 앱이 자동으로 연결을 마무리합니다.
- 출시 전: Android 릴리스 키 SHA-256을 `hosting/public/.well-known/assetlinks.json`에 추가, `invite.html`의 스토어 링크 채우기

## 푸시 알림 (선택, Blaze 필요)
- 운동 완료(알림 보내기 켜고 저장), 콕 찌르기, 연결 요청/완료 → 짝꿍에게 푸시
- iOS: APNs 키(.p8)를 Firebase 콘솔 › 클라우드 메시징에 업로드
- Blaze 없이도 앱은 정상 동작하고, 같은 내용이 홈 배너로 보입니다.

## 데모 짝꿍 (개발용)
짝꿍 없이 커플 화면을 확인하려면: 홈 › 아바타 › 커플 화면 맨 아래 **데모 짝꿍으로 미리 보기**.
가짜 짝꿍 "소연"의 3주치 운동 · 몸 기록이 화면에만 나타나며 Firebase에는 저장되지 않습니다. 디버그 빌드에서만 보입니다.

## iOS 빌드 참고
- **rsync**: 이 개발 환경(macOS 27)에서는 Xcode 빌드 중 rsync가 갓 만들어진 바이너리를 열 때 `Operation not permitted`가 간헐적으로 납니다. `ios/tools/rsync`가 재시도 후 `ditto`로 대신 복사하며, Flutter 빌드 단계와 CocoaPods(`Podfile`의 `post_integrate`)가 이 래퍼를 쓰도록 설정되어 있습니다.
- **CocoaPods 오류** `Unicode Normalization not appropriate for ASCII-8BIT`: `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install`
- **Apple 로그인 / 푸시 / Live Activity**는 실기기에서 확인하세요. Xcode › Signing에서 Runner와 WorkoutWidget 두 타깃 모두 팀을 지정해야 합니다.

## 테스트
```bash
flutter analyze
flutter test                     # 운동 타이머 · 기록 포맷 · 몸 지표 · 초대 링크 · 화면 렌더
cd functions && npm test         # 푸시 토큰 정리 · 초대 연결 판단
```
