require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const promClient = require('prom-client');

// ============================================================
// Prometheus 메트릭 계측 (관측 추가 — 로직 변경 없음)
// ============================================================
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register, prefix: 'event_' });

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [register],
});

const app = express();
// [포트 규칙] event-service: 3002
const PORT = process.env.PORT || 3002;

// [SRE 4] JSON Structured Logging
const logger = {
    info: (msg, extra = {}) => console.log(JSON.stringify({
        timestamp: new Date().toISOString(), level: 'INFO', service: 'event-svc', message: msg, ...extra
    })),
    error: (msg, extra = {}) => console.error(JSON.stringify({
        timestamp: new Date().toISOString(), level: 'ERROR', service: 'event-svc', message: msg, ...extra
    }))
};

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

const pool = mysql.createPool({
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    connectionLimit: parseInt(process.env.DB_CONN_LIMIT) || 3,
    charset: 'utf8mb4' // 한글/아랍어 등 멀티바이트 mojibake 방지 (커넥션을 utf8mb4로 고정)
});

// [M5] 토큰 회전 시 구 토큰 노출 창을 줄이기 위해 TTL을 60초로 둔다.
const AUTH_CACHE_TTL_MS = 60000;
const authCache = new Map();
const authMiddleware = async (req, res, next) => {
    const token = req.headers['authorization']?.replace('Bearer ', '');
    if (!token) return res.status(401).json({ error: 'Unauthorized', message: '로그인 필요' });

    const now = Date.now();
    const cached = authCache.get(token);
    if (cached && (now - cached.ts < AUTH_CACHE_TTL_MS)) {
        req.user = cached.user;
        return next();
    }

    try {
        const [rows] = await pool.execute("SELECT id FROM users WHERE token = ?", [token]);
        if (rows.length === 0) return res.status(401).json({ error: 'Unauthorized', message: '로그인 필요' });

        const user = rows[0];
        authCache.set(token, { user, ts: now });
        req.user = user;
        next();
    } catch (err) {
        logger.error("Auth system error", { error: err.message });
        res.status(500).json({ error: "Auth System Error" });
    }
};

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
app.get('/health/live', (req, res) => res.status(200).send('OK'));
app.get('/health/ready', async (req, res) => {
    try { await pool.query('SELECT 1'); res.status(200).send('Ready'); }
    catch (err) { res.status(503).send('DB Not Ready'); }
});

// 목록 조회
app.get('/events', async (req, res) => {
    const lang = req.query.lang || 'en';
    try {
        const [rows] = await pool.execute(`
            SELECT e.id, e.category, e.image_url,
                COALESCE(tt.translated_text, e.title)       AS title,
                COALESCE(td.translated_text, e.description)  AS description,
                COALESCE(tl.translated_text, e.location)     AS location,
                (tt.translated_text IS NULL) AS fallback_flag,
                (SELECT COALESCE(SUM(s.remaining_capacity), 0)
                   FROM event_slots s WHERE s.event_id = e.id) AS slots_left,
                (SELECT MIN(s.slot_datetime)
                   FROM event_slots s WHERE s.event_id = e.id) AS next_slot
            FROM events e
            LEFT JOIN translations tt
              ON e.id = tt.event_id AND tt.target_lang = ? AND tt.field_name = 'title'
            LEFT JOIN translations td
              ON e.id = td.event_id AND td.target_lang = ? AND td.field_name = 'description'
            LEFT JOIN translations tl
              ON e.id = tl.event_id AND tl.target_lang = ? AND tl.field_name = 'location'
            ORDER BY e.id
        `, [lang, lang, lang]);

        // [SRE 메트릭 추가] PM 쿼리 1: 다국어 데이터가 없어 폴백될 때 로그 (R-2 시연용)
        rows.forEach(row => {
            if (row.fallback_flag && lang !== 'ko') {
                logger.info('translate_fallback_used', { target_lang: lang, event_id: row.id });
            }
            delete row.fallback_flag; // 클라이언트 응답에서는 제외
        });

        res.json(rows);
    } catch (err) {
        logger.error(`Fetch events failed`, { error: err.message });
        res.status(500).json({ error: "Internal Server Error" });
    }
});

// 상세 조회
app.get('/events/:event_id', async (req, res) => {
    const { event_id } = req.params;
    const lang = req.query.lang || 'en';

    try {
        const [eventRows] = await pool.execute(`
            SELECT e.id, e.category, e.image_url, e.main_image_url,
                COALESCE(t1.translated_text, e.title) AS title,
                COALESCE(t2.translated_text, e.description) AS description,
                COALESCE(t3.translated_text, e.location) AS location,
                (t1.translated_text IS NULL) AS fallback_flag
            FROM events e
            LEFT JOIN translations t1 ON e.id = t1.event_id AND t1.target_lang = ? AND t1.field_name = 'title'
            LEFT JOIN translations t2 ON e.id = t2.event_id AND t2.target_lang = ? AND t2.field_name = 'description'
            LEFT JOIN translations t3 ON e.id = t3.event_id AND t3.target_lang = ? AND t3.field_name = 'location'
            WHERE e.id = ?
        `, [lang, lang, lang, event_id]);

        if (eventRows.length === 0) return res.status(404).json({ error: "Not Found", message: "존재하지 않는 이벤트" });

        const event = eventRows[0];

        // [SRE 메트릭 추가] 폴백 로그
        if (event.fallback_flag && lang !== 'ko') {
            logger.info('translate_fallback_used', { target_lang: lang, event_id: event.id });
        }
        delete event.fallback_flag;

        const [slots] = await pool.execute(
            "SELECT id, slot_datetime, max_capacity, remaining_capacity, version FROM event_slots WHERE event_id = ? ORDER BY slot_datetime",
            [event_id]
        );

        event.slots = slots;
        res.json(event);
    } catch (err) {
        logger.error("Fetch event detail failed", { event_id, error: err.message });
        res.status(500).json({ error: "Internal Server Error" });
    }
});

const server = app.listen(PORT, '0.0.0.0', () => {
    logger.info(`Event Service started on port ${PORT}`);
});

server.keepAliveTimeout = 75000;
server.headersTimeout = 80000;

process.on('SIGTERM', () => {
    logger.info("SIGTERM received. Closing server...");
    server.close(async () => {
        await pool.end();
        process.exit(0);
    });
});