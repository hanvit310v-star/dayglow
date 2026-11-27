# Dayglow

날씨와 상황에 따라 분위기가 바뀌는 캘린더 (국민대학교 AX-Startup 부트캠프 실습)

### 🌐 바로 사용하기
**https://dayglow.vercel.app**

PC·폰 브라우저에서 열면 됩니다. 일정은 각자의 브라우저에만 저장돼요.
위치를 허용하면 내 위치의 날씨(맑음·비·눈·안개 등)와 시간대(새벽·노을·밤)에 맞춰 배경과 색이 바뀌어요.

> 이름이 바뀔 때 고칠 곳은 `20261126_캘린더_PRD.md`의 **15장**에 정리돼 있어요.

---

## 주요 기능
- 월·주·일 보기, 일정 추가·수정·삭제, 반복 일정, 겹침 경고
- 할 일 (마감일 있음·없음), 카테고리, 검색
- **분위기**: 날씨 테마 7종 + 상황 변화(시간대·폭염·한파·강풍·바쁜 날·일정 진행 중), 직접 고르기 패널
- 넓은 화면은 6:4 배치, 폰은 세로 배치

## 폴더 구조
| 경로 | 내용 |
|---|---|
| `app/` | **Flutter 앱** (안드로이드·iOS·웹을 한 코드로) |
| `app/lib/core` | 날짜 계산·데이터 모양 |
| `app/lib/data` | 저장소 (기기 안 저장) |
| `app/lib/mood` | 날씨·상황 판단 (Open-Meteo) |
| `app/lib/ui` | 화면 |
| `index.html` | 처음 만든 웹 버전 (설계도) |
| `20261126_캘린더_PRD.md` | 기획 문서 |
| `app do it list.md` | 안드로이드 출시 작업 목록 |

## 배포
- `main` 브랜치에 올리면 Vercel이 Flutter 3.50.1을 받아 `app/`을 웹으로 빌드해 위 주소에 자동 반영해요 (`vercel.json`).
- 직접 배포: `npx vercel@65.14.0 deploy --prod`

## 사용한 자료
- 글꼴: [Pretendard](https://github.com/orioncactus/pretendard) (SIL OFL 1.1) — 자주 쓰는 2,350자로 줄이고 `DayglowSans`로 이름을 바꿔 포함 (`app/assets/fonts/OFL-Pretendard-LICENSE.txt`)
- 날씨: [Open-Meteo](https://open-meteo.com) (비상업 무료)
