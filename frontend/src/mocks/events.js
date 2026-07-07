/**
 * Mock catalogue used in mock-first mode. Shapes mirror what the *fixed*
 * backend should eventually return (see docs/BACKEND_REVIEW.md issue #17:
 * the real GET /events is missing image_url / dates / capacity).
 *
 * Images are real uploads under /assets/popups (served from public/).
 *   - image      → home card + 상세 상단 타이틀 카드(히어로) (`_title`)
 *   - mainImage  → 이벤트 상세 서술 끝 이미지 (`_main`)
 *   - subtitle   → 한줄 소개 = 제목과 동일
 *   - description → 서술 전체 (이벤트 상세 섹션). 이모지는 DB(utf8) 호환 위해 제거, 줄바꿈만 유지.
 */
export const CATEGORIES = [
  { id: "all",        labelKey: "cat.all",        icon: "grid" },
  { id: "popup",      labelKey: "cat.popup",      icon: "bag" },
  { id: "kpop",       labelKey: "cat.kpop",       icon: "music" },
  { id: "exhibition", labelKey: "cat.exhibition", icon: "image" },
  { id: "experience", labelKey: "cat.experience", icon: "star" },
];

export const EVENTS = [
  {
    id: 1,
    category: "popup",
    badge: "POP-UP",
    title: "OASIS POP-UP MARKET",
    subtitle: "OASIS POP-UP MARKET",
    description: `OASIS 팝업스토어 in 마포
오아시스 팬들, 이번 팝업은 진짜 지갑 조심

재결합 투어 1주년을 기념해 오아시스 팝업 마켓이 서울에 열립니다.

'Oasis Live '25 Tour' 공식 MD부터
아디다스 콜라보 의류, 포스터, 바이닐까지
100개 이상의 아이템을 특별한 가격으로 만날 수 있어요.

음악 마니아라면 그냥 지나치기 어려울
16일간의 특별한 팝업

LOUNGE M. (서울 마포구 서강로 78, MPMG 2F)
2026.07.04 ~ 2026.07.19
14:00 ~ 20:00

Oasis Live '25 Tour 공식 MD
아디다스 콜라보 의류
포스터 및 음반 판매
100여 종 이상의 한정 아이템
특별가로 만나볼 수 있는 팝업 마켓`,
    image: "/assets/popups/oasis_title.jpg",
    mainImage: "/assets/popups/oasis_main.jpg",
    dateRange: "2026.07.04 - 07.19",
    dateShort: "07.04 - 07.19",
    hours: "매일 14:00 - 20:00",
    location: "서울 마포구 서강로 78",
    slots: [
      { id: 11, slot_datetime: "2026-07-04T14:00:00", remaining_capacity: 500, max_capacity: 500, version: 0 },
      { id: 12, slot_datetime: "2026-07-11T14:00:00", remaining_capacity: 500, max_capacity: 500, version: 0 },
    ],
    limited: false,
    slotsLeft: 1000,
  },
  {
    id: 2,
    category: "kpop",
    badge: "K-POP",
    title: "베이비몬스터 월드 투어 춤(CHOOM)",
    subtitle: "베이비몬스터 월드 투어 춤(CHOOM)",
    description: `2026-27 BABYMONSTER WORLD TOUR [춤 (CHOOM)] IN SEOUL 추가 오픈 안내
2026-27 BABYMONSTER WORLD TOUR [춤 (CHOOM)] IN SEOUL에 보내주신 MONSTIEZ 여러분의 성원에 감사드립니다.

더 많은 MONSTIEZ 여러분을 만나고자 하는 아티스트의 의견과 부정 거래로 확인된 좌석의 재배분 및 공연장 운영 효율성 제고를 통해 판매가 보류되었던 일부 좌석을 추가 오픈합니다. (시야제한석 포함)

시야제한석의 경우 시야제한의 정도는 좌석의 위치 및 개인의 관람 기준에 따라 차이가 있을 수 있으며, 공연 당일 해당 좌석의 시야 제한에 따른 취소, 변경 및 환불은 어떠한 사유로도 불가하니 이 점 유의하여 신중히 예매해 주시기 부탁드립니다.`,
    image: "/assets/popups/baby_title.jpg",
    mainImage: "/assets/popups/baby_main.jpg",
    dateRange: "2026.06.26 - 06.28",
    dateShort: "06.26 - 06.28",
    hours: "20:00 시작",
    location: "서울특별시 송파구 올림픽로 25 (잠실동)",
    slots: [
      { id: 21, slot_datetime: "2026-06-26T20:00:00", remaining_capacity: 10000, max_capacity: 10000, version: 0 },
      { id: 22, slot_datetime: "2026-06-27T20:00:00", remaining_capacity: 10000, max_capacity: 10000, version: 0 },
      { id: 23, slot_datetime: "2026-06-28T20:00:00", remaining_capacity: 10000, max_capacity: 10000, version: 0 },
    ],
    limited: false,
    slotsLeft: 30000,
  },
  {
    id: 3,
    category: "experience",
    badge: "EXPERIENCE",
    title: "신라면분식 더 팩토리",
    subtitle: "신라면분식 더 팩토리",
    description: `신라면분식 더 팩토리 팝업스토어 in 성수
라면 좋아하는 사람들 성수에 꼭 가야 할 이유 생겼다

신라면 40주년을 맞아 글로벌 신라면 분식이 드디어 한국에 상륙했습니다.

갓 만든 라면부터 수출 전용 제품,
직접 만드는 굿즈와 내 얼굴이 들어간 라면 패키지까지 즐길 거리가 가득해요.

신라면 똠얌, 순라면, 볶음너구리 등
평소 궁금했던 해외 제품과 스페셜 메뉴도 만나볼 수 있어서 라면 덕후라면 그냥 지나치기 어려울 듯

스테이지 X 성수 52 (서울 성동구 성수동)
2026.06.20 ~ 2026.07.20
11:00 ~ 20:00

갓 만든 신라면 제품 판매
직접 만드는 굿즈 & 스페셜 에디션
나만의 라면 패키지 제작
산라 탄탄면·아사도 삼겹 라면 등 특별 메뉴
신라면 똠얌·순라면·볶음너구리 등 수출 전용 제품`,
    image: "/assets/popups/sin_title.jpg",
    mainImage: "/assets/popups/sin_main.jpg",
    dateRange: "2026.06.20 - 07.20",
    dateShort: "06.20 - 07.20",
    hours: "매일 09:00 - 18:00",
    location: "서울 성동구 성수일로4길 52",
    slots: [
      { id: 31, slot_datetime: "2026-06-20T09:00:00", remaining_capacity: 1000, max_capacity: 1000, version: 0 },
      { id: 32, slot_datetime: "2026-07-01T09:00:00", remaining_capacity: 1000, max_capacity: 1000, version: 0 },
    ],
    limited: false,
    slotsLeft: 2000,
  },
  {
    id: 4,
    category: "exhibition",
    badge: "EXHIBITION",
    title: "렘브란트에서 고야까지",
    subtitle: "렘브란트에서 고야까지",
    description: `렘브란트에서 고야까지 : 톨레도 미술관 명작展 in 더현대서울
16세기 중반부터 19세기 중반까지,
약 300년에 걸친 유럽 미술사의 흐름을 한자리에서 만날 수 있는 대규모 전시가 열렸어요

이번 전시는 미국 5대 미술관 중 하나로 꼽히는
톨레도 미술관(Toledo Museum of Art)의 대표 소장품들을 국내 최초로 선보이는 자리라고 해요

렘브란트, 고야, 엘 그레코, 자크 루이 다비드, 터너 등
서양 미술사를 대표하는 거장들의 원화 50여 점을 직접 감상할 수 있다고 합니다

르네상스 이후 바로크, 로코코, 신고전주의, 낭만주의까지 이어지는
유럽 회화사의 중요한 흐름을 따라가며 작품들을 깊이 있게 감상할 수 있는 전시

고전 미술 좋아하는 사람들은 물론,
유럽 미술사의 분위기를 직접 느껴보고 싶은 사람들에게도 추천해요

전시 장소
더현대 서울 ALT.1

전시 일정
2026.06.22 ~ 2026.07.04

3세기에 걸친 명작들을 한 공간에서 만날 수 있는 특별한 기회
천천히 작품 몰입하며 보기 좋은 전시 같아요!`,
    image: "/assets/popups/ram_title.jpg",
    mainImage: "/assets/popups/ram_main.jpg",
    dateRange: "2026.06.22 - 07.04",
    dateShort: "06.22 - 07.04",
    hours: "매일 10:30 - 20:00",
    location: "서울특별시 영등포구 여의대로 108 (여의도동) 더현대서울",
    slots: [
      { id: 41, slot_datetime: "2026-06-22T10:30:00", remaining_capacity: 500, max_capacity: 500, version: 0 },
      { id: 42, slot_datetime: "2026-06-29T10:30:00", remaining_capacity: 500, max_capacity: 500, version: 0 },
    ],
    limited: false,
    slotsLeft: 1000,
  },
];

export const findEvent = (id) => EVENTS.find((e) => String(e.id) === String(id));
