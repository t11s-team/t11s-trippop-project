-- =================================================================================
-- [운영 가이드 주의 주석]
-- 본 seed 파일은 explicit ID 지정과 대량 인서트 기법이 융합된 비멱등성 스크립트입니다.
-- 초기 인프라 구성 단계에서 init 스키마와 함께 딱 1회만 가동해야 합니다.
-- k6 테스트 반복 실행 사이에는 절대 본 파일을 재수행하지 마시고, db_reset.sql만 호출하십시오.
--
-- 이미지: events.image_url 은 홈 카드(_title) 이미지. 상세 메인(_main)은 프론트 mock에서만
-- 분리 사용하며, 실백엔드에는 main 이미지 컬럼이 없어 상세 메인도 _title 로 폴백한다.
-- 번역: title/description/location 의 en 만 시드. zh/ar 는 event-service/reservation-service
-- 모두 COALESCE 폴백이라 한글 원문으로 안전하게 표시된다(추후 보강 가능).
-- =================================================================================

USE kculture;

-- ---------------------------------------------------------
-- 1. 기준 샘플 데이터 (초기 가동 및 기본 데이터 정제)
-- ---------------------------------------------------------

-- 1-1. 기준 유저 데이터 (INSERT IGNORE 적용)
INSERT IGNORE INTO users (id, email, name, password_hash, language, role, token) VALUES
(1, 'kim@example.com',   '김길동', '$2a$10$x7z5DvqEvNHvaRTPgtwSXeYWmzbTeZal.jBWEyBQyirGbJbS8AzEO', 'en', 'admin', '550e8400-e29b-41d4-a716-446655440000'),
(2, 'hong@example.com',  '홍길동', '$2a$10$x7z5DvqEvNHvaRTPgtwSXeYWmzbTeZal.jBWEyBQyirGbJbS8AzEO', 'ja', 'user',  '678e8400-e29b-41d4-a716-446655440001'),
(3, 'emma@test.com',     'Emma',  '$2a$10$x7z5DvqEvNHvaRTPgtwSXeYWmzbTeZal.jBWEyBQyirGbJbS8AzEO', 'en', 'user',  '11111111-1111-1111-1111-111111111111'),
(4, 'yuki@test.com',     'Yuki',  '$2a$10$x7z5DvqEvNHvaRTPgtwSXeYWmzbTeZal.jBWEyBQyirGbJbS8AzEO', 'ja', 'user',  '22222222-2222-2222-2222-222222222222'),
(5, 'wei@test.com',      'Wei',   '$2a$10$x7z5DvqEvNHvaRTPgtwSXeYWmzbTeZal.jBWEyBQyirGbJbS8AzEO', 'zh', 'user',  '33333333-3333-3333-3333-333333333333'),
(6, 'lucas@test.com',    'Lucas', '$2a$10$x7z5DvqEvNHvaRTPgtwSXeYWmzbTeZal.jBWEyBQyirGbJbS8AzEO', 'en', 'user',  '44444444-4444-4444-4444-444444444444'),
(7, 'sofia@test.com',    'Sofia', '$2a$10$x7z5DvqEvNHvaRTPgtwSXeYWmzbTeZal.jBWEyBQyirGbJbS8AzEO', 'en', 'user',  '55555555-5555-5555-5555-555555555555');

-- 1-2. 이벤트 데이터 (INSERT IGNORE 적용)
--   1=OASIS(팝업) 2=베이비몬스터(K-POP) 3=신라면분식(체험형, k6 부하 대상) 4=렘브란트전(전시)
--   description 은 "헤딩 첫 줄 + 본문" 구조. 프론트가 첫 줄을 상단 소개(subtitle)로,
--   나머지를 상세 본문으로 분리해 보여준다. 전시일정은 seed 슬롯 일정에 맞춰 정정됨.
INSERT IGNORE INTO events (id, title, description, location, category, image_url, main_image_url) VALUES
(1, 'OASIS POP-UP MARKET', 'OASIS 팝업스토어 in 마포
오아시스 팬들, 이번 팝업은 진짜 지갑 조심

재결합 투어 1주년을 기념해 오아시스 팝업 마켓이 서울에 열립니다.

''Oasis Live ''25 Tour'' 공식 MD부터
아디다스 콜라보 의류, 포스터, 바이닐까지
100개 이상의 아이템을 특별한 가격으로 만날 수 있어요.

음악 마니아라면 그냥 지나치기 어려울
16일간의 특별한 팝업

LOUNGE M. (서울 마포구 서강로 78, MPMG 2F)
2026.07.04 ~ 2026.07.19
14:00 ~ 20:00

Oasis Live ''25 Tour 공식 MD
아디다스 콜라보 의류
포스터 및 음반 판매
100여 종 이상의 한정 아이템
특별가로 만나볼 수 있는 팝업 마켓', '서울 마포구 서강로 78', 'popup', '/assets/popups/oasis_title.jpg', '/assets/popups/oasis_main.jpg'),
(2, '베이비몬스터 월드 투어 춤(CHOOM)', '2026-27 BABYMONSTER WORLD TOUR [춤 (CHOOM)] IN SEOUL 추가 오픈 안내
2026-27 BABYMONSTER WORLD TOUR [춤 (CHOOM)] IN SEOUL에 보내주신 MONSTIEZ 여러분의 성원에 감사드립니다.

더 많은 MONSTIEZ 여러분을 만나고자 하는 아티스트의 의견과 부정 거래로 확인된 좌석의 재배분 및 공연장 운영 효율성 제고를 통해 판매가 보류되었던 일부 좌석을 추가 오픈합니다. (시야제한석 포함)

시야제한석의 경우 시야제한의 정도는 좌석의 위치 및 개인의 관람 기준에 따라 차이가 있을 수 있으며, 공연 당일 해당 좌석의 시야 제한에 따른 취소, 변경 및 환불은 어떠한 사유로도 불가하니 이 점 유의하여 신중히 예매해 주시기 부탁드립니다.', '서울특별시 송파구 올림픽로 25 (잠실동)', 'kpop', '/assets/popups/baby_title.jpg', '/assets/popups/baby_main.jpg'),
(3, '신라면분식 더 팩토리', '신라면분식 더 팩토리 팝업스토어 in 성수
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
신라면 똠얌·순라면·볶음너구리 등 수출 전용 제품', '서울 성동구 성수일로4길 52', 'experience', '/assets/popups/sin_title.jpg', '/assets/popups/sin_main.jpg'),
(4, '렘브란트에서 고야까지', '렘브란트에서 고야까지 : 톨레도 미술관 명작展 in 더현대서울
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
천천히 작품 몰입하며 보기 좋은 전시 같아요!', '서울특별시 영등포구 여의대로 108 (여의도동) 더현대서울', 'exhibition', '/assets/popups/ram_title.jpg', '/assets/popups/ram_main.jpg');

-- 1-3. 기준 타임슬롯 데이터 (재실행 시에도 잔여수량 원복 및 버전 0 동기화)
INSERT INTO event_slots (id, event_id, slot_datetime, remaining_capacity, max_capacity, version) VALUES
(11, 1, '2026-07-04 14:00:00', 500,   500,   0),
(12, 1, '2026-07-11 14:00:00', 500,   500,   0),
(21, 2, '2026-06-26 20:00:00', 10000, 10000, 0),
(22, 2, '2026-06-27 20:00:00', 10000, 10000, 0),
(23, 2, '2026-06-28 20:00:00', 10000, 10000, 0),
(31, 3, '2026-06-20 09:00:00', 1000,  1000,  0),
(32, 3, '2026-07-01 09:00:00', 1000,  1000,  0),
(41, 4, '2026-06-22 10:30:00', 500,   500,   0),
(42, 4, '2026-06-29 10:30:00', 500,   500,   0)
ON DUPLICATE KEY UPDATE
    remaining_capacity = VALUES(remaining_capacity),
    version = 0;

-- 1-4. 다국어 번역 데이터 (en/zh/ar 시드 — admin 미경유라 AWS Translate가 안 돌아 수동 주입.
--      미입력 언어는 event/reservation-service 모두 COALESCE 폴백으로 한글 원문 노출.)
INSERT IGNORE INTO translations (event_id, field_name, target_lang, translated_text) VALUES
-- 1. OASIS POP-UP MARKET (팝업)
(1, 'title',       'en', 'OASIS Pop-up Market'),
(1, 'title',       'zh', 'OASIS 快闪市集'),
(1, 'title',       'ar', 'سوق OASIS المؤقت'),
(1, 'description', 'en', 'A lifestyle pop-up market with an urban-oasis concept.'),
(1, 'description', 'zh', '以都市绿洲为概念的生活方式快闪市集。'),
(1, 'description', 'ar', 'سوق مؤقت لأسلوب الحياة بمفهوم واحة حضرية.'),
(1, 'location',    'en', '78 Seogang-ro, Mapo-gu, Seoul'),
(1, 'location',    'zh', '首尔麻浦区西江路78'),
(1, 'location',    'ar', '78 سيوغانغ-رو، مابو-غو، سيول'),
-- 2. 베이비몬스터 월드 투어 춤(CHOOM) (K-POP)
(2, 'title',       'en', 'BABYMONSTER World Tour ''CHOOM'''),
(2, 'title',       'zh', 'BABYMONSTER 世界巡演 ''CHOOM'''),
(2, 'title',       'ar', 'جولة BABYMONSTER العالمية ''CHOOM'''),
(2, 'description', 'en', 'BABYMONSTER World Tour ''CHOOM'' live performance.'),
(2, 'description', 'zh', 'BABYMONSTER 世界巡演 ''CHOOM'' 现场演出。'),
(2, 'description', 'ar', 'عرض حي لجولة BABYMONSTER العالمية ''CHOOM''.'),
(2, 'location',    'en', '25 Olympic-ro, Songpa-gu, Seoul (Jamsil-dong)'),
(2, 'location',    'zh', '首尔松坡区奥林匹克路25（蚕室洞）'),
(2, 'location',    'ar', '25 أولمبيك-رو، سونغبا-غو، سيول (جامسيل-دونغ)'),
-- 3. 신라면분식 더 팩토리 (체험형)
(3, 'title',       'en', 'Shin Ramyun Bunsik: The Factory'),
(3, 'title',       'zh', '辛拉面粉食 The Factory'),
(3, 'title',       'ar', 'شين راميون بونسيك: المصنع'),
(3, 'description', 'en', 'A Shin Ramyun-themed snack experience space, The Factory.'),
(3, 'description', 'zh', '以辛拉面为主题的小吃体验空间 The Factory。'),
(3, 'description', 'ar', 'مساحة لتجربة الوجبات الخفيفة بطابع شين راميون، المصنع.'),
(3, 'location',    'en', '52 Seongsuil-ro 4-gil, Seongdong-gu, Seoul'),
(3, 'location',    'zh', '首尔城东区圣水一路4街52'),
(3, 'location',    'ar', '52 سيونغسويل-رو 4-غيل، سيونغدونغ-غو، سيول'),
-- 4. 렘브란트에서 고야까지 (전시)
(4, 'title',       'en', 'From Rembrandt to Goya'),
(4, 'title',       'zh', '从伦勃朗到戈雅'),
(4, 'title',       'ar', 'من رامبرانت إلى غويا'),
(4, 'description', 'en', 'From Rembrandt to Goya — masterpieces by the great masters.'),
(4, 'description', 'zh', '从伦勃朗到戈雅——巨匠们的名画展。'),
(4, 'description', 'ar', 'من رامبرانت إلى غويا — روائع كبار الأساتذة.'),
(4, 'location',    'en', '108 Yeoui-daero, Yeongdeungpo-gu, Seoul (The Hyundai Seoul)'),
(4, 'location',    'zh', '首尔永登浦区汝矣大路108（汝矣岛洞）The Hyundai Seoul'),
(4, 'location',    'ar', '108 يويدايرو، يونغديونغبو-غو، سيول (ذا هيونداي سيول)');

-- 1-5. 기준 예약 데이터 (복합 UNIQUE 제약에 걸리지 않도록 INSERT IGNORE 처리)
INSERT IGNORE INTO reservations (user_id, event_slot_id, status, idempotency_key) VALUES
(1, 11, 'confirmed', '754b2d91-381a-464a-9b16-5faef4316d82');

-- ---------------------------------------------------------
-- 2. 테스트 데이터 세트 (id 대역은 9xx로 통일, event_id=3 신라면에 연결)
-- ---------------------------------------------------------

-- 2-1. 동시성 테스트용 슬롯 (재실행 시 수량 1, 버전 0 원복)
INSERT INTO event_slots (id, event_id, slot_datetime, remaining_capacity, max_capacity, version) VALUES
(901, 3, '2026-11-15 14:00:00', 1, 1, 0)
ON DUPLICATE KEY UPDATE
    remaining_capacity = VALUES(remaining_capacity),
    version = 0;

-- 2-2. HPA 부하 테스트용 대량 슬롯 24개 생성 (재실행 시 수량 5000, 버전 0 원복)
--   24 × 5,000 = 120,000 정원. 12분 런(피크 1200rps) 기준 피크 구간에서 ~100초간
--   201 insert 가 지속된 뒤 정원 소진 → sold-out 409가 찍힌다(HPA 가 8 pod 까지 반응할 시간 확보).
--   유저(6,000)×슬롯(24)=144,000 조합이 정원(120,000)보다 많아, 중복-유저 409가 아니라
--   진짜 "마감(sold out)" 409로 빠진다.
INSERT INTO event_slots (id, event_id, slot_datetime, remaining_capacity, max_capacity, version)
WITH RECURSIVE slot_generator AS (
    SELECT 920 AS id, 0 AS hr
    UNION ALL
    SELECT id + 1, hr + 1 FROM slot_generator WHERE id < 943
)
SELECT
    id,
    3 AS event_id,
    DATE_ADD('2026-12-01 00:00:00', INTERVAL hr HOUR) AS slot_datetime,
    5000 AS remaining_capacity,
    5000 AS max_capacity,
    0 AS version
FROM slot_generator
ON DUPLICATE KEY UPDATE
    remaining_capacity = VALUES(remaining_capacity),
    version = 0;

-- 2-3. HPA용 가상 유저 6,000명 대량 생성 (INSERT IGNORE 적용)
--   유저 수 = 쓰기 부하 상한(UNIQUE(user_id,slot)). 정원(120,000)보다 조합(144,000)을 크게 둬
--   정원이 먼저 동나도록 한다. (MariaDB는 max_recursive_iterations 기본 무제한이라 6,000행 OK)
INSERT IGNORE INTO users (id, email, name, password_hash, language, role, token)
WITH RECURSIVE user_generator AS (
    SELECT 901 AS id, 1 AS n
    UNION ALL
    SELECT id + 1, n + 1 FROM user_generator WHERE n < 6000
)
SELECT
    id,
    CONCAT('loadtest', LPAD(n, 4, '0'), '@test.com') AS email,
    CONCAT('Loadtest_', LPAD(n, 4, '0')) AS name,
    '$2a$10$x7z5DvqEvNHvaRTPgtwSXeYWmzbTeZal.jBWEyBQyirGbJbS8AzEO' AS password_hash,
    'en' AS language,
    'user' AS role,
    CONCAT('loadtest-token-', LPAD(n, 4, '0')) AS token
FROM user_generator;
