# app do it list — 안드로이드 앱 출시 작업 목록

> **사용법**: 나중에 Claude에게 이 파일 전체를 붙여 넣고 "이 목록대로 이어서 진행해줘"라고 말하면 됩니다.
> 완료한 항목은 `[ ]`를 `[x]`로 바꿔 두세요. 마지막 갱신: 2026-11-26

---

## 0. 지금까지의 상황 (Claude가 먼저 읽을 부분)

### 프로젝트
- 작업 폴더: `~/Desktop/dayglow` (예전 이름 `calendar-vibe-coding`, 그 전엔 `캘린더 바이브코딩` — 한글·띄어쓰기 경로는 빌드 오류 위험이라 변경함)
- 기획 문서: `20261126_캘린더_PRD.md` (특히 **14장 "앱 출시 계획"**)
- 예전 웹 버전(설계도): `index.html` — 백업·알림·단축키 등 아직 앱에 옮기지 않은 기능의 참고용
- **Flutter 앱**: `app/` (iOS·안드로이드·웹을 한 코드로)
  - `lib/core` 날짜 계산·데이터 모양 / `lib/data` 저장소(기기 안) / `lib/mood` 날씨·상황 / `lib/ui` 화면
  - 글꼴: `assets/fonts/DayglowSans-*.otf` (Pretendard를 2,350자로 줄여 이름 변경, SIL OFL 1.1, 라이선스 파일 포함)

### 결정된 사항
- **안드로이드 먼저 출시**, iOS는 나중 (`ios` 폴더는 유지)
- PC는 **웹 링크**로 사용 (설치형 PC 프로그램은 필요해질 때 추가)
- 위치는 ① 날씨·상황 테마 ② 일정 장소 기록에만 사용, 백그라운드 위치는 쓰지 않음, 안드로이드는 대략적인 위치(COARSE)만
- 로그인은 Supabase(이메일 + 구글). 애플 로그인은 iOS 출시 때
- 날씨: Open-Meteo (무료·키 없음, **비상업 조건** → 유료화·광고 시 약관 재확인)

### 개발 환경 (이 Mac)
| 항목 | 상태 |
|---|---|
| Flutter | ✅ 3.50.1, `~/development/flutter` (터미널 경로 미설정 → 명령은 `~/development/flutter/bin/flutter` 전체 경로로 사용) |
| 웹 빌드 | ✅ Chrome 준비됨 |
| Android SDK | ⚠️ `~/Library/Android/sdk`에 일부만 있음 (cmdline-tools 없음) |
| Java(JDK) | ❌ 없음 (Android Studio에 포함) |
| Xcode | ⏸ 보류 (iOS는 나중) |
| 디스크 여유 | 약 26GB (Android Studio 설치에는 충분, 에뮬레이터까지면 빠듯) |
| Material 패키지 | 이 Flutter 버전은 `package:material_ui/material_ui.dart` 사용 (예전 `package:flutter/material.dart` 아님) |

### 배포 상태
- **웹**: ✅ https://dayglow-app.vercel.app (Vercel 프로젝트 `dayglow`, GitHub와 연결됨)
  - **재배포 = GitHub `main`에 올리기만 하면 자동** (Vercel이 Flutter 3.50.1을 받아 `app/`을 빌드, 약 2분). 설정: 맨 위 폴더의 `vercel.json`, `.vercelignore`
  - Flutter 버전을 올리면 `vercel.json`의 `-b 3.50.1`도 같이 바꾸기
- **GitHub**: ✅ https://github.com/hanvit310v-star/dayglow (공개 저장소, `main` 브랜치)
  - 올리지 않는 파일: `.gitignore` 참고 (`.env*`, `.vercel`, `*.jks`, `key.properties`, `.claude/`, 빌드 결과물)
  - ⚠️ 공개 저장소이므로 서명 키·비밀번호·토큰이 절대 커밋되지 않게 주의
- **Google Play**: ❌ 아직

### 앱에 있는 기능 / 없는 기능
- ✅ 월·주·일 보기, 일정 추가·수정·삭제·겹침 경고, 할 일(마감일 있음·없음), 카테고리, 검색, 넓은 화면 6:4 / 폰 세로 배치, 날씨 테마 7종·효과, 상황 변화(시간대·기온·강풍·바쁜 날·일정 중), 분위기 패널, 한글 글꼴
- ❌ 일정 알림(폰 알림), 백업 불러오기·내보내기, 로그인·동기화, 일정 장소 기록, 위젯, 앱 아이콘

---

## 1. 개발 환경 준비
- [ ] **Android Studio 설치** (공식: developer.android.com/studio) — JDK·cmdline-tools 포함
  - 설치 후 SDK Manager에서 **Android SDK Command-line Tools** 체크
  - 실제 안드로이드 폰이 있으면 에뮬레이터 생략 가능(용량 절약): 폰 설정 → 휴대전화 정보 → 빌드번호 7번 탭 → 개발자 옵션 → USB 디버깅 켜기
- [ ] 라이선스 동의: `~/development/flutter/bin/flutter doctor --android-licenses` (사용자가 직접 읽고 동의)
- [ ] `~/development/flutter/bin/flutter doctor` 에서 **Android toolchain ✓** 확인
- [ ] (선택) 터미널 경로 설정 — 사용자가 직접:
  `echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc`

## 2. 앱 정체성 확정 (⚠️ 첫 업로드 전에! 앱 식별자는 출시 후 변경 불가)
- [ ] **앱 이름** 정하기 → `app/android/app/src/main/AndroidManifest.xml`의 `android:label` (현재 `Dayglow`)
- [ ] **앱 식별자(패키지 이름)** 정하기 (예: `kr.본인도메인.calendar`) → 현재 값 `com.dayglow.dayglow` (2026-11-27 변경, 출시 전 최종 확인)
  - 바꿀 곳: `app/android/app/build.gradle.kts`의 `namespace`, `applicationId` / `MainActivity.kt`의 `package` 줄과 폴더 경로 (`android/app/src/main/kotlin/com/dayglow/dayglow/`)
- [ ] **앱 아이콘** 만들기 (512×512 PNG 원본) → `flutter_launcher_icons` 패키지로 모든 크기 생성
- [ ] 웹 제목도 맞추기: `app/web/index.html`의 `<title>`, `app/web/manifest.json`의 `name`
- [ ] 버전: `app/pubspec.yaml`의 `version: 1.0.0+1` (+ 뒤 숫자는 올릴 때마다 증가)

## 3. 첫 출시에 넣을 기능 결정 (사용자에게 먼저 확인)
> 추천: 지금 기능으로 먼저 출시 → 아래는 업데이트로 추가. 로그인이 없으면 Play 개인정보 항목이 간단해짐
- [ ] 일정 알림 (`flutter_local_notifications`, 안드로이드 13 이상은 알림 권한 `POST_NOTIFICATIONS` 요청 + 정확한 시간 알림 권한 검토)
- [ ] 백업 불러오기 (웹 버전 `index.html`의 JSON 백업 형식 그대로 → `lib/core/models.dart`가 같은 이름 사용 중)
- [ ] 로그인·동기화 (Supabase 무료 가입은 사용자가 직접, 이메일 + 구글, **앱 안 계정 삭제** 포함)
- [ ] 일정 장소 기록 (사용자가 버튼을 누를 때만, ⚠️ 서버 저장 시 위치정보법 검토 — PRD 14-4)
- [ ] 안드로이드 위젯 (Kotlin + `home_widget` 패키지)
- [ ] 단축키 (웹·태블릿 키보드용)

## 4. 앱 서명 키 (⚠️ 잃어버리면 앱 업데이트 불가 — 안전한 곳에 백업)
- [ ] 업로드 키 만들기 — **비밀번호가 들어가므로 사용자가 직접 터미널에서 실행**:
  ```
  "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" -genkey -v -keystore ~/dayglow-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```
- [ ] `app/android/key.properties` 작성 (사용자가 직접 비밀번호 입력, **절대 GitHub·채팅에 올리지 않기**):
  ```
  storePassword=(직접 입력)
  keyPassword=(직접 입력)
  keyAlias=upload
  storeFile=/Users/morecatplz/dayglow-upload.jks
  ```
- [ ] `app/android/.gitignore`에 `key.properties`, `*.jks` 들어 있는지 확인
- [ ] `app/android/app/build.gradle.kts`에 release 서명 설정 추가 (현재 `signingConfig = signingConfigs.getByName("debug")` → key.properties를 읽는 release 설정으로) — Flutter 공식 문서 "Build and release an Android app" 참고
- [ ] Play Console에서 **Play 앱 서명** 사용 (구글이 최종 서명 키 보관 → 업로드 키 분실 시 재설정 가능)

## 5. 출시용 빌드
- [ ] `cd app && ~/development/flutter/bin/flutter analyze` → 문제 0건
- [ ] `~/development/flutter/bin/flutter test` → 통과
- [ ] 실제 폰에서 실행 확인: `~/development/flutter/bin/flutter run --release` (위치 권한·날씨 테마·한글 입력 확인)
- [ ] 출시 파일 만들기: `~/development/flutter/bin/flutter build appbundle --release`
  → 결과: `app/build/app/outputs/bundle/release/app-release.aab`
- [ ] 크기 확인: `~/development/flutter/bin/flutter build appbundle --analyze-size`

## 6. 스토어 등록 자료
- [ ] **개인정보처리방침 웹페이지** (Play 필수) — 작성해서 Vercel에 함께 올리기 (예: `/privacy.html`)
  - 포함: 위치(대략적, 날씨 확인용, 저장 안 함, Open-Meteo로 약 1km 단위 좌표 전송), 기기 내 저장 데이터(일정·할 일), 문의 이메일, (로그인 넣으면) 계정·서버 저장·삭제 방법
- [ ] **데이터 보안 양식** 답변 준비: 위치(대략적) 수집 여부·목적·공유 여부, 암호화 전송(https) 여부
- [ ] 스토어 문구: 앱 이름(30자), 짧은 설명(80자), 자세한 설명(4,000자)
- [ ] 그래픽: 앱 아이콘 512×512, 대표 이미지 1024×500, 폰 스크린샷 2장 이상
- [ ] 콘텐츠 등급 설문, 타깃 연령, 광고 포함 여부(없음)
- [ ] 오픈소스 라이선스 고지 (Pretendard OFL 등 — 앱 설정에 "오픈소스 라이선스" 메뉴 추가 권장, Flutter `showLicensePage` 사용)

## 7. GitHub (코드 보관·백업)
- [x] 저장소 연결·최신화 (2026-11-26, https://github.com/hanvit310v-star/dayglow)
- [x] Vercel 자동 배포 연결 (main에 올리면 웹 링크 자동 갱신)
- [ ] (선택) 저장소를 비공개로 바꿀지 결정 — 출시 앱 코드 공개 여부. 비공개로 바꿔도 Vercel 자동 배포는 그대로 동작
- [ ] (선택) GitHub 저장소 오른쪽 "About" → Website에 웹 주소 입력 (사용자가 GitHub 화면에서 직접)
- [ ] 서명 키 작업(4번) 전에 `git status`로 `key.properties`, `*.jks`가 목록에 없는지 확인

## 8. Google Play 출시 (사용자가 직접 하는 부분 위주)
- [ ] Google Play Console 개발자 등록 (1회 $25, 본인 인증)
- [ ] 앱 만들기 → 2·6번 자료 입력
- [ ] **비공개 테스트**: 개인 계정(2023-11-13 이후 생성)은 **테스터 12명 이상이 14일 연속 참여**해야 정식 출시 신청 가능
  - 테스터 이메일 12명 이상 모으기 (예: 부트캠프 동료), 14일 동안 테스트 유지
  - 최신 조건 확인: https://support.google.com/googleplay/android-developer/answer/14151465
- [ ] `.aab` 업로드 → 비공개 테스트 트랙 배포
- [ ] 14일 후 **프로덕션 액세스 신청** → 승인 후 정식 출시
- [ ] 출시 전 최종 점검: 대상 API 수준(targetSdk) 요구 사항, 위치 권한 설명 문구, 개인정보처리방침 링크 작동

## 9. 출시 후 (나중에)
- [ ] iOS 출시: Xcode 설치(디스크 40GB 이상 확보), 애플 개발자($99/년), 애플 로그인 추가, 앱 안 계정 삭제
- [ ] 위젯, 로그인 동기화 등 업데이트
- [ ] 웹 주소에 내 도메인 연결 (선택)

---

### 주의 (항상)
- 비밀번호·API 키·서명 키 비밀번호는 **채팅에 붙여 넣지 않기**. 터미널이나 해당 사이트에 직접 입력
- `key.properties`, `*.jks`, `.env.local`, `.vercel` 폴더는 GitHub에 올리지 않기
