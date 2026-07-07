require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');

const promClient = require('prom-client');

// ============================================================
// Prometheus 메트릭 계측 (관측 추가 — 로직 변경 없음)
// ============================================================
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register, prefix: 'reservation_' });

// 골든 시그널 - HTTP 요청 카운터
const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

// 골든 시그널 - HTTP 응답 시간 (p99 계산용)
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [register],
});

// 정합성 데모용 카운터
const reservationResultTotal = new promClient.Counter({
  name: 'reservation_result_total',
  help: 'Reservation attempt results',
  labelNames: ['result'],  // success / conflict / soldout / error
  registers: [register],
});

// 토큰 인증 캐시 hit/miss — hit rate 대시보드용.
// hit rate = hits / (hits + misses). 부하 시 토큰 재요청이 TTL(60s) 안에 몰려 95%+ 기대.
const authCacheResultTotal = new promClient.Counter({
  name: 'auth_cache_result_total',
  help: 'Token auth cache lookups by result',
  labelNames: ['result'],  // hit / miss
  registers: [register],
});

// 정합성 데모용 게이지 (잔여 좌석 추적)
// ⚠️ 데모 전용: slot_id 는 DB row id 라 라벨에 넣으면 슬롯 증가에 따라 시계열이
//    무한 증가(카디널리티 폭증 + prom-client 메모리 누수)한다. 데모 slot 풀은
//    [1..9]로 bounded 라 안전. 운영 전환 시에는 이 라벨/메트릭을 제거하거나
//    slot_id 없는 집계 메트릭으로 재설계할 것.
//    event_title 은 대시보드 가시성용 라벨. slot→event 가 N:1 이라 slot_id 에
//    함수적으로 종속되어 시계열 수를 늘리지 않는다(설명용 라벨).
const slotRemainingCapacity = new promClient.Gauge({
  name: 'slot_remaining_capacity',
  help: 'Remaining capacity per event slot (DEMO ONLY — slot_id label is high-cardinality)',
  labelNames: ['slot_id', 'event_title'],
  registers: [register],
});

const app = express();
// [규칙 1 / 포트 규칙] reservation-service: 3001
const PORT = process.env.PORT || 3001;

// [규칙 4] JSON Structured Logging
const logger = {
    info: (msg, extra = {}) => console.log(JSON.stringify({
        timestamp: new Date().toISOString(), level: 'INFO', service: 'reservation-svc', message: msg, ...extra
    })),
    error: (msg, extra = {}) => console.error(JSON.stringify({
        timestamp: new Date().toISOString(), level: 'ERROR', service: 'reservation-svc', message: msg, ...extra
    }))
};

// [규칙 3 / BACKEND_REVIEW #10] CORS: 다중 origin + 안전한 기본값 (미설정 시 전체 허용 금지)
const corsOrigins = (process.env.CORS_ORIGIN || 'http://localhost:5173')
    .split(',').map((s) => s.trim()).filter(Boolean);
app.use(cors({
    origin: corsOrigins,
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'x-idempotency-key']
}));
app.use(express.json());

// HTTP 메트릭 자동 수집 미들웨어
app.use((req, res, next) => {
  if (req.path === '/metrics' || req.path.startsWith('/health')) {
    return next();
  }
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    // 카디널리티 방지: 매칭된 라우트는 템플릿(/path/:id), 미매칭(404)은 raw 경로(id 포함) 대신 상수로 축소
    const route = req.route ? req.route.path : 'unmatched';
    const labels = { method: req.method, route, status: String(res.statusCode) };
    httpRequestsTotal.inc(labels);
    end(labels);
  });
  next();
});

// [규칙 1, 2] 환경변수 DB 접속
// connectionLimit 기본값 5 = 계획서 "DB 커넥션 풀(HPA 반영)" 기준.
// k8s 매니페스트/.env 에서 DB_CONN_LIMIT=5 로 명시할 것 (HPA max 6 × 5 = 30).
const pool = mysql.createPool({
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    connectionLimit: parseInt(process.env.DB_CONN_LIMIT) || 5,
    waitForConnections: true,
    connectTimeout: 5000,
    charset: 'utf8mb4' // 한글/아랍어 등 멀티바이트 mojibake 방지 (커넥션을 utf8mb4로 고정)
});

// 낙관적 락 자동 재시도 횟수 (계획서 4 실패표: Version Conflict → 자동 3회)
const MAX_RETRY = 3;

// [규칙 12] UUID 토큰 authMiddleware + 메모리 캐시 + DB 조회
// [M5] 토큰 회전 시 구 토큰 노출 창을 줄이기 위해 TTL을 60초로 둔다.
const AUTH_CACHE_TTL_MS = 60000;
const authCache = new Map();
const authMiddleware = async (req, res, next) => {
    const token = req.headers['authorization']?.replace('Bearer ', '');
    // 계획서 실패표: Unauthenticated → 401 "로그인 필요"
    if (!token) return res.status(401).json({ error: 'Unauthorized', message: '로그인 필요' });

    const now = Date.now();
    const cached = authCache.get(token);
    if (cached && (now - cached.ts < AUTH_CACHE_TTL_MS)) {
        authCacheResultTotal.inc({ result: 'hit' });
        req.user = cached.user;
        return next();
    }
    // 캐시에 없거나 TTL 만료 → DB 조회 (miss)
    authCacheResultTotal.inc({ result: 'miss' });

    try {
        const [rows] = await pool.execute("SELECT id FROM users WHERE token = ?", [token]);
        // 토큰이 유효하지 않으면 동일하게 미인증으로 처리 (401, 메시지 일관)
        if (rows.length === 0) return res.status(401).json({ error: 'Unauthorized', message: '로그인 필요' });

        const user = rows[0];
        authCache.set(token, { user, ts: now });
        req.user = user;
        next();
    } catch (err) {
        logger.error(`Auth system error: ${err.message}`);
        res.status(500).json({ error: "Auth System Error" });
    }
};

app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
});

// [규칙 5] Health Check
app.get('/health/live', (req, res) => res.status(200).send('OK'));
app.get('/health/ready', async (req, res) => {
    try { await pool.query('SELECT 1'); res.status(200).send('Ready'); }
    catch (err) { res.status(503).send('Database connection failed'); }
});

// 멱등 재생 헬퍼: 같은 idempotency_key 의 기존 예약을 다시 조회해 200으로 반환.
// 멱등성 계약 = "같은 키 재시도 → 같은 성공 응답"  (계획서 실패표: Idempotency Hit → 200, 기존 결과 반환)
async function respondIdempotent(conn, res, idempotencyKey) {
    const [rows] = await conn.execute(
        "SELECT id, event_slot_id, status FROM reservations WHERE idempotency_key = ?",
        [idempotencyKey]
    );
    if (rows.length > 0) {
        const r = rows[0];
        res.status(200).json({
            reservation_id: r.id,
            slot_id: r.event_slot_id,
            status: r.status,
            idempotent: true,
            message: "이미 처리된 요청입니다 (기존 예약 반환)"
        });
        return true;
    }
    return false;
}

// [규칙 6, 7] Parameterized Query & 낙관적 락 기반 예약 로직
// version 은 클라이언트가 아니라 서버가 직접 조회한다 (계획서 5-6 step 2 설계 그대로).
app.post('/reservations', authMiddleware, async (req, res) => {
    const { slot_id } = req.body;
    const idempotencyKey = req.headers['x-idempotency-key'];

    if (!idempotencyKey) {
        return res.status(400).json({ error: "Idempotency key required in headers" });
    }
    if (!slot_id) {
        return res.status(400).json({ error: "slot_id required" });
    }

    const conn = await pool.getConnection();
    try {
        // [계층 2] 멱등성 사전 SELECT — 순차 재시도(클라이언트 타임아웃 후 재요청)용 빠른 경로.
        // ※ 동시 같은-키 버스트는 트랜잭션 격리로 서로를 못 보므로 이 계층으로는 못 막는다.
        //    그 경우는 [계층 5] DB UNIQUE 가 최종 방어선.
        if (await respondIdempotent(conn, res, idempotencyKey)) return;

        // [계층 3·4] version 충돌 시 자동 재시도 (최대 3회)
        for (let attempt = 1; attempt <= MAX_RETRY; attempt++) {
            // step 2: 서버가 현재 잔여/버전 조회 (대시보드 라벨용 event_title 동반 조회)
            const [slots] = await conn.execute(
                `SELECT s.remaining_capacity, s.version, e.title AS event_title
                 FROM event_slots s
                 JOIN events e ON s.event_id = e.id
                 WHERE s.id = ?`,
                [slot_id]
            );
            if (slots.length === 0) {
                return res.status(404).json({ error: "Slot not found", message: "존재하지 않는 슬롯" });
            }
            const { remaining_capacity, version, event_title } = slots[0];

            // 매진은 재시도 무의미 → fast-fail (계획서: Sold Out 409 "마감되었습니다")
            if (remaining_capacity <= 0) {
                reservationResultTotal.inc({ result: 'soldout' });
                return res.status(409).json({ error: "Sold out", message: "마감되었습니다" });
            }

            await conn.beginTransaction();
            try {
                // [계층 3] 원자적 조건부 차감 = 오버부킹 방지의 핵심(행 잠금으로 직렬화)
                // [계층 4] version 일치 요구 = 동시 수정 감지(재시도 분기용)
                const [result] = await conn.execute(
                    `UPDATE event_slots
                     SET remaining_capacity = remaining_capacity - 1, version = version + 1
                     WHERE id = ? AND remaining_capacity > 0 AND version = ?`,
                    [slot_id, version]
                );

                if (result.affectedRows === 0) {
                    await conn.rollback();
                    // 실패 원인 구분: 그 사이 매진? 아니면 version 충돌(동시 수정)?
                    const [recheck] = await conn.execute(
                        "SELECT remaining_capacity FROM event_slots WHERE id = ?",
                        [slot_id]
                    );
                    if (recheck.length === 0 || recheck[0].remaining_capacity <= 0) {
                        reservationResultTotal.inc({ result: 'soldout' });
                        return res.status(409).json({ error: "Sold out", message: "마감되었습니다" });
                    }
                    // 잔여>0 인데 실패 → version 충돌 → 다음 루프에서 재시도
                    logger.info("Version conflict, retrying", { slot_id, attempt });
                    continue;
                }

                // [계층 5·6] reservations INSERT
                //  - idempotency_key UNIQUE / unique_user_slot UNIQUE 위반은 catch 에서 분류
                //  - UPDATE+INSERT 를 한 트랜잭션으로 묶어 부분 차감(좌석만 깎이고 예약 누락) 방지
                const [ins] = await conn.execute(
                    "INSERT INTO reservations (user_id, event_slot_id, idempotency_key, status) VALUES (?, ?, ?, 'confirmed')",
                    [req.user.id, slot_id, idempotencyKey]
                );

                await conn.commit();
                reservationResultTotal.inc({ result: 'success' });
                slotRemainingCapacity.set(
                    { slot_id: String(slot_id), event_title },
                    remaining_capacity - 1
                );
                logger.info("Reservation success", {
                    reservation_id: ins.insertId, slot_id, user_id: req.user.id, idempotencyKey, attempt
                });
                return res.status(201).json({
                    reservation_id: ins.insertId,
                    slot_id,
                    status: "confirmed",
                    message: "Reservation confirmed"
                });
            } catch (txErr) {
                await conn.rollback();
                // [계층 5] DB UNIQUE 위반을 500이 아니라 정확한 상태코드로 매핑
                if (txErr.code === 'ER_DUP_ENTRY') {
                    const m = txErr.sqlMessage || '';
                    if (m.includes('idempotency_key')) {
                        // 동시 같은-키 경쟁에서 다른 요청이 먼저 커밋 → 멱등 재생(200)
                        reservationResultTotal.inc({ result: 'conflict' });
                        if (await respondIdempotent(conn, res, idempotencyKey)) return;
                        return res.status(409).json({ error: "Duplicate request", message: "이미 예약하셨습니다" });
                    }
                    if (m.includes('unique_user_slot')) {
                        // 같은 사용자가 다른 키로 같은 슬롯 재예약 → 진짜 중복 예약
                        reservationResultTotal.inc({ result: 'conflict' });
                        return res.status(409).json({ error: "Already reserved", message: "이미 예약하셨습니다" });
                    }
                    reservationResultTotal.inc({ result: 'conflict' });
                    return res.status(409).json({ error: "Duplicate", message: "중복 요청" });
                }
                throw txErr; // 그 외 예외는 바깥 catch(500)
            }
        }

        // 재시도 3회 모두 version 충돌 (계획서 실패표: Version Conflict 409 "다시 시도해주세요")
        logger.error("Version conflict retry exhausted", { slot_id, idempotencyKey });
        reservationResultTotal.inc({ result: 'conflict' });
        return res.status(409).json({ error: "Version conflict", message: "다시 시도해주세요" });

    } catch (err) {
        reservationResultTotal.inc({ result: 'error' });
        logger.error(`Reservation failed: ${err.message}`);
        res.status(500).json({ error: "Internal Server Error" });
    } finally {
        conn.release();
    }
});

// [BACKEND_REVIEW #21] 내 예약 목록 — 예약 탭에서 사용 (이벤트/슬롯 조인)
app.get('/reservations', authMiddleware, async (req, res) => {
    try {
        // 예약 목록 제목도 사용자 언어로 번역(translations 조인). 번역행 없으면 원문(e.title).
        // event-service(홈/상세)는 lang으로 번역하는데 여기만 원문을 내려서
        // "예약 탭 제목만 미번역" 버그가 있었다.
        const lang = (req.query.lang || '').trim();
        const [rows] = await pool.execute(`
            SELECT r.id, r.status, r.created_at, r.event_slot_id,
                   s.slot_datetime, s.event_id,
                   COALESCE(tr.translated_text, e.title) AS event_title,
                   e.image_url AS event_image, e.location
            FROM reservations r
            JOIN event_slots s ON r.event_slot_id = s.id
            JOIN events e ON s.event_id = e.id
            LEFT JOIN translations tr
              ON tr.event_id = e.id
             AND tr.field_name = 'title'
             AND tr.target_lang = ?
            WHERE r.user_id = ?
            ORDER BY r.created_at DESC
        `, [lang, req.user.id]);
        res.json(rows);
    } catch (err) {
        logger.error(`List reservations failed: ${err.message}`);
        res.status(500).json({ error: "Internal Server Error" });
    }
});

// [잔여 좌석 게이지 동기화] DB가 단일 진실원본(SoT).
//  성공 시점 .set() 만으로는 (1) 첫 예약 전까지 No data, (2) 다중 레플리카에서 파드별
//  부분값, (3) admin-service/E2E 등 다른 경로 변경 미반영 문제가 있다.
//  → 기동 즉시 + 주기적으로 DB 전 슬롯을 읽어 게이지를 동기화한다.
//  다중 파드는 같은 DB를 읽어 동일 값을 노출하므로, 대시보드는 max by(slot_id,event_title)로 집계.
const SLOT_GAUGE_REFRESH_MS = 15000;
async function refreshSlotCapacityGauge() {
    try {
        const [rows] = await pool.query(
            `SELECT s.id AS slot_id, s.remaining_capacity, e.title AS event_title
             FROM event_slots s JOIN events e ON s.event_id = e.id`
        );
        for (const r of rows) {
            slotRemainingCapacity.set(
                { slot_id: String(r.slot_id), event_title: r.event_title },
                r.remaining_capacity
            );
        }
    } catch (err) {
        logger.error(`Slot capacity gauge refresh failed: ${err.message}`);
    }
}

const server = app.listen(PORT, '0.0.0.0', () => {
    logger.info(`Reservation Service started on port ${PORT}`);
    refreshSlotCapacityGauge(); // 기동 즉시 1회 → 첫 예약 전에도 현재 잔여가 패널에 표시됨
});

// [규칙 10, 11] ALB Timeout 설정
server.keepAliveTimeout = 75000;
server.headersTimeout = 80000;

// 주기적 동기화 (admin-service/E2E 등 다른 경로의 차감도 반영)
const slotGaugeTimer = setInterval(refreshSlotCapacityGauge, SLOT_GAUGE_REFRESH_MS);

// [규칙 8] SIGTERM graceful shutdown (server.close + pool.end)
process.on('SIGTERM', () => {
    logger.info("SIGTERM received. Closing server gracefully...");
    clearInterval(slotGaugeTimer);
    server.close(async () => {
        await pool.end();
        process.exit(0);
    });
});