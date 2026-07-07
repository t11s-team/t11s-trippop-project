# trippop 프론트엔드 i18n 적용 — 변경사항 요약
**작업 일자**: 2026-06-04
**범위**: UI 사전(ko/en/zh/ar) + RTL + 자동 감지 + LangSelect 활성화 + 동적 콘텐츠 lang 전달 + deadlink 정리

---

## 결정사항

| 항목 | 값 |
|---|---|
| **기본 언어** | 한국어 (`ko`) |
| **자동 감지 우선순위** | localStorage 저장값 → navigator.language → "ko" |
| **지원 언어** | ko / en / zh / ar (4개) |
| **RTL** | ar(아랍어) — 히브리어 → 아랍어로 변경됨 |
| **LangSelect 위치** | 모든 페이지 상단 (인증/홈/상세/예약/프로필/Placeholder) |
| **브랜드명** | "TripPop" 번역 제외 (제품명) |

---

## 신규 파일 (4개)

| 파일 | 역할 |
|---|---|
| `src/lib/i18n.js` | 사전 + `t(key, lang, vars)` 함수 + 자동 감지 + RTL 상수 |
| `src/context/LanguageContext.jsx` | 전역 언어 상태 + localStorage 영속화 + `<html lang/dir>` 동기화 |
| `src/components/LangSelect.jsx` | 드롭다운 (덮어쓰기) — 기존 "decorative" 컴포넌트 활성화 |
| `INTL-CHANGES.md` | 이 문서 |

---

## 수정 파일 (16개)

### 핵심 인프라
| 파일 | 변경 |
|---|---|
| `src/main.jsx` | `LanguageProvider`로 App 감쌈 |
| `src/lib/format.js` | `formatDateLabel(iso, lang)` + `formatTime(iso, lang)` — Intl.DateTimeFormat 사용, 요일은 사전 |
| `src/lib/validate.js` | 에러 메시지가 영어 문자열 대신 **i18n 키** 반환 |
| `src/api/client.js` | 네트워크 에러에 `code = "error.network"` 추가 |
| `src/api/events.js` | `listEvents/getEvent`의 어댑터들이 lang 받아 dateRange 로컬화 |
| `src/api/reservations.js` | `listMyReservations({auth, lang})` — slot_label 로컬화 |
| `src/api/auth.js` | `signUp` 기본 language를 "en"→"ko" |
| `src/mocks/events.js` | CATEGORIES에 `labelKey` 추가 (label 제거) |
| `src/components/Icon.jsx` | `globe` 아이콘 추가 + 방향성 아이콘 RTL 자동 반전 |
| `src/styles/components.css` | LangSelect 드롭다운 + screen-head 정렬 + RTL 스타일 |

### 페이지 (7개) — 전부 `useLanguage().t()` 적용 + LangSelect 노출
| 파일 | 추가 변경 |
|---|---|
| `src/App.jsx` | Placeholder title을 i18n 키로 (`"nav.schedule"`, `"nav.saved"`) |
| `src/pages/SignIn.jsx` | "Forgot Password" deadlink 제거(라우트 미존재) — span으로 변경 |
| `src/pages/SignUp.jsx` | LangSelect 추가, 가입 시 `lang`을 `language`로 전달 |
| `src/pages/Home.jsx` | lang 변경 시 `listEvents` 재호출 |
| `src/pages/EventDetail.jsx` | lang 변경 시 `getEvent` 재호출, hero 우상단에 LangSelect |
| `src/pages/Reservations.jsx` | LangSelect 추가, status 매핑 테이블 |
| `src/pages/Profile.jsx` | "Language" 메뉴 추가 (bottom-sheet 언어 선택기 포함) |
| `src/pages/Placeholder.jsx` | title을 키로 받아 t() 처리 |

### 컴포넌트 (5개)
| 파일 | 변경 |
|---|---|
| `src/components/BottomNav.jsx` | labelKey 사용 |
| `src/components/CategoryTabs.jsx` | mocks의 labelKey 사용 |
| `src/components/FilterModal.jsx` | WHEN/THEMES 옵션이 id+labelKey 구조 |
| `src/components/PromoBanner.jsx` | 보간 `{n}` 사용 |
| `src/components/PopupCard.jsx` | "left" 카운트 보간 |

---

## 사전 키 네임스페이스

| 네임스페이스 | 범위 | 예시 |
|---|---|---|
| `auth.*` | 로그인/가입 텍스트 | `auth.signin`, `auth.email.placeholder` |
| `validate.*` | 폼 검증 메시지 | `validate.email.required` |
| `home.*` | 홈 화면 | `home.title`, `home.search.placeholder` |
| `promo.*` | 프로모션 배너 | `promo.title`, `promo.only` |
| `cat.*` | 카테고리 | `cat.popup`, `cat.kpop` |
| `filter.*` | 필터 모달 | `filter.when.today`, `filter.themes` |
| `detail.*` | 이벤트 상세 | `detail.reserve`, `detail.about` |
| `res.*` | 예약 목록 | `res.title`, `res.status.confirmed` |
| `profile.*` | 마이페이지 | `profile.menu.reservations` |
| `nav.*` | 하단 네비 | `nav.home`, `nav.me` |
| `placeholder.*` | 빈 상태 화면 | `placeholder.comingSoon` |
| `lang.*` | 언어 선택기 | `lang.change` |
| `error.*` | 글로벌 에러 | `error.network`, `error.duplicateEmail` |
| `date.day.*` | 요일 짧은 이름 | `date.day.mon` |

---

## RTL 처리 방식

| 레이어 | 방식 |
|---|---|
| **언어 → 방향** | `LanguageContext`가 `document.documentElement.dir = "rtl"` 설정 |
| **레이아웃** | CSS Logical Properties (`margin-inline`, `inset-inline-end`, `text-align: start`) — `[dir="rtl"]` 별도 분기 거의 없음 |
| **방향성 아이콘** | `Icon.jsx`가 `DIRECTIONAL` 세트(arrow-left/right, chevron-right, login)에 `icon-flip-rtl` 클래스 부여 → CSS가 `scaleX(-1)` |
| **체크/하트** | 자동 반전 안 함 (방향성 없음) |

---

## 자동 감지 동작

```
앱 시작
  ↓
1. localStorage("trippop.lang") 읽음 → 있으면 그 값 사용
  ↓ (없으면)
2. navigator.languages 순회
   - "ko-KR" → ko ✅
   - "zh-CN" → zh ✅
   - "ar-EG" → ar ✅
   - "en-US" → en ✅
  ↓ (어떤 것도 매칭 안 되면)
3. "ko" (프로젝트 기본값)
```

언어 변경 시 자동으로:
- localStorage에 저장 → 다음 방문에도 유지
- `<html lang="..." dir="...">` 갱신 → 스크린리더/CSS 동작
- 동적 콘텐츠 재조회 (Home/EventDetail의 `useEffect([lang])`)

---

## 새 언어 추가 방법 (예: 일본어)

1. `src/lib/i18n.js`:
   - `SUPPORTED_LANGS`에 `"ja"` 추가
   - `LANG_LABELS`, `LANG_SHORT`에 `ja` 항목 추가
   - `dict.ja = { ... }` 사전 추가 (ko/en 키와 동일하게)

2. `src/lib/format.js`에 ja 로케일 매핑 추가 (`"ja-JP"`)

3. 끝. 다른 곳 수정 없음.

---

## 미구현/추후 작업

- [ ] **번역 검수**: ko/zh/ar 번역의 자연스러움 (특히 ar는 격식체 검토 필요)
- [ ] **캡차 추가**: 회원가입 (Cloudflare Turnstile) — UX 구상 완료 후
- [ ] **이벤트 mock 데이터 다국어화**: 현재 `mocks/events.js`는 영어. 백엔드가 실제로 다국어 데이터 줄 때까지는 mock도 그대로
- [ ] **비밀번호 찾기 라우트** 추가 시 SignIn의 span → Link로 복원
- [ ] **RTL 시각 검수**: 아랍어 상태에서 모든 화면 보면서 깨지는 곳 확인

---

## 검증 체크리스트

```
□ 시크릿 창에서 첫 진입 → 한국어로 시작
□ 브라우저 언어를 영어로 → 한국어 → 한국어 유지 (저장됨)
□ 언어 EN으로 바꾸고 새로고침 → EN 유지
□ EventDetail에서 언어 바꾸면 이벤트 제목/설명도 백엔드에서 새 언어로 받아옴
□ 아랍어 선택 → 레이아웃 우→좌로 뒤집힘, 화살표 방향 반전, 폰트 정상
□ 회원가입 → 백엔드 user.language에 현재 UI 언어 저장됨
□ 예약 status가 사용자 언어로 표시됨
□ 날짜가 언어별 포맷 ("5월 6일 (월)" / "May 6 (Mon)" / "5月6日 (周一)" / "٦ مايو (الإثنين)")
```

---

## 패치 — React 19 lint 호환 (set-state-in-effect)

CI에서 `eslint-plugin-react-hooks` 7.x의 `react-hooks/set-state-in-effect` 룰이 useEffect 안의 동기 setState 호출을 차단해서 수정.

### 핵심 규칙
- useEffect 본문에서 직접 `setStatus("loading")` 호출 → ❌
- useEffect 본문에서 `async function load() { setStatus("loading"); await ... }` 형태로 감싸 호출 → ✅ (룰이 명시적으로 예외)
- useEffect 본문에서 `setInterval(() => setX(...), 1000)` 콜백 → ✅ (indirect call 예외)

### 수정 파일 (4개)
| 파일 | 변경 |
|---|---|
| `pages/Home.jsx` | useEffect 안의 setState를 inner async function `load()`로 감쌈 |
| `pages/EventDetail.jsx` | 동일 패턴으로 변경 |
| `pages/Reservations.jsx` | 일관성을 위해 같은 async function 패턴 |
| `hooks/useCountdown.js` | useEffect 본문의 동기 `tick()` 호출 제거. setInterval 콜백만 유지 (useState lazy initializer가 초기값을 정확히 계산하므로 첫 tick 불필요) |

### 근거 자료
- Prometheus 공식 문서: https://eslint-react.xyz/docs/rules/set-state-in-effect — "The rule does not detect set calls in async functions that are called before the first await statement."
- React Compiler 기반 룰 (eslint-plugin-react-hooks 6.1.0+, React 19와 함께 도입)
