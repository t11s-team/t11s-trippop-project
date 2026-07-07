# 팝업 실제 이미지 — 드롭 가이드

이 폴더(`frontend/public/assets/popups/`)에 **실제 팝업 이미지**를 넣습니다.
빌드 시 그대로 S3+CloudFront로 서빙되며, URL은 루트 기준 `/assets/popups/<파일명>` 입니다.
(실제 이미지 제작 전까지는 mock 이미지 `public/mock/*.svg`가 그대로 사용됩니다.)

---

## 1. 권장 규격 (표시 px는 폰 프레임 430px 기준, 모두 `object-fit: cover`)

| 슬롯 | 표시 위치 | 표시 px | 비율 | **권장 내보내기** | 형식/용량 |
|---|---|---|---|---|---|
| **메인 이미지** (`events.image_url`) | 홈 카드 + 상세 히어로 | ~280×210 / ~430×280 | **4:3** | **1200×900** | WebP/JPG, <100KB |
| **갤러리 ×3** (공통) | 상세 `.gallery img` | ~398×200 | **2:1** | **1200×600** | WebP/JPG, <120KB |
| **맵 ×1** (공통) | 상세 `.map img` | ~398×170 | ~7:3 | **1200×520** | WebP/JPG/PNG, <120KB |

- 형식: 사진은 **WebP(우선) / JPG**, sRGB, 품질 ~80%. PNG는 로고·투명 배경만(사진 PNG는 용량 폭증).
- 레티나 대비 표시 px의 2~3배로 내보낸 값이 위 "권장 내보내기"입니다.

## 2. ⚠️ 메인 이미지 1장이 카드(4:3)+히어로(3:2)를 겸함
`event.image`(= `image_url`) 하나가 홈 카드와 상세 히어로 **양쪽**에 쓰입니다.
→ 이벤트당 **이미지 1장**, **피사체를 중앙**에 두고 **가장자리 여백**을 주세요(두 비율로 잘려도 안 깨지게).
카드/히어로를 따로 쓰려면 컬럼 추가(스키마 변경)가 필요 → 데모에선 권장하지 않음.

## 3. 네이밍 컨벤션
```
/assets/popups/<event-slug>.webp        # 메인 (예: hanbok.webp, kpop-dance.webp)
/assets/popups/gallery/<slug>-1.webp    # 갤러리 (필요 시 이벤트별, 현재는 공통)
/assets/popups/map/<slug>.webp          # 맵 (현재는 공통)
```
현재 seed 이벤트: `1=경복궁 한복 체험`, `2=K-POP 댄스 클래스`.

## 4. 넣고 나서 연결하는 법 (스키마 변경 없음)
1. **메인 이미지** → `events.image_url` 값 교체
   - 운영(실백엔드): `scripts/db_seed.sql`의 해당 이벤트 `image_url`을 `/assets/popups/hanbok.webp` 등으로
   - 또는 admin 등록 시 `image_url` 필드에 경로 입력
2. **갤러리/맵**(전 이벤트 공통) → `frontend/src/api/events.js`의 `DISPLAY_DEFAULTS`에서
   `image` / `gallery` / `map` 경로를 새 파일로 교체
3. `image_url`은 `VARCHAR(500)`이라 경로·CDN 풀 URL 모두 수용 → 컬럼 변경 불필요.

## 5. 체크리스트
- [ ] **데모 모드 확인** — 운영 빌드는 `USE_MOCK=false`(강제) → 이미지는 **백엔드 `image_url`**에서. dev(`USE_MOCK=true`)는 `mocks/events.js`에서. 바꿀 파일이 달라짐
- [ ] 장수: 이벤트 N장(현재 2) + 공통 갤러리 3장 + 맵 1장
- [ ] 형식 WebP/JPG · sRGB · 품질 ~80% · 용량 예산 준수
- [ ] 크롭 안전영역(피사체 중앙·여백)
- [ ] 실제 팝업 사진이면 **사용권/저작권** 확인
- [ ] (선택) 갤러리 `<img>` alt 텍스트 채우기(a11y) — 카드는 title 자동

---
> 이 README는 개발용 가이드입니다. 빌드에 포함돼 `/assets/popups/README.md`로 노출되니, 운영 배포 전 신경 쓰이면 삭제해도 됩니다.
