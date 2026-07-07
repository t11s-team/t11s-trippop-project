require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const { TranslateClient, TranslateTextCommand } = require('@aws-sdk/client-translate');

const promClient = require('prom-client');

// ============================================================
// Prometheus 메트릭 계측 (관측 추가 — 로직 변경 없음)
// ============================================================
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register, prefix: 'admin_' });

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
// [규칙 1 / 포트 규칙] admin-service: 3004
const PORT = process.env.PORT || 3004;

// [SRE 규칙 4] JSON Structured Logging
const logger = {
    info: (msg, extra = {}) => console.log(JSON.stringify({
        timestamp: new Date().toISOString(), level: 'INFO', message: msg, service: 'admin-svc', ...extra
    })),
    error: (msg, extra = {}) => console.error(JSON.stringify({
        timestamp: new Date().toISOString(), level: 'ERROR', message: msg, service: 'admin-svc', ...extra
    }))
};

// [SRE 규칙 3 / BACKEND_REVIEW #10] CORS: 다중 origin + 안전한 기본값
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

// [SRE 규칙 1, 2] 환경변수 DB 접속 (USER: admin)
const pool = mysql.createPool({
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER,      // admin 반영
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,  // kculture 반영
    connectionLimit: parseInt(process.env.DB_CONN_LIMIT) || 3, // [규칙 2]
    waitForConnections: true,
    connectTimeout: 5000,
    charset: 'utf8mb4' // 한글/아랍어 등 멀티바이트 INSERT mojibake 방지 (커넥션을 utf8mb4로 고정)
});

const SOURCE_LANG = 'ko';
// 프론트 지원 언어(SUPPORTED_LANGS = ko/en/zh/ar)에서 소스(ko) 제외한 타깃.
// ja는 프론트 미지원이라 제거(죽은 번역행+AWS 비용), ar 추가(아랍어 폴백→한글 노출 방지).
const TARGET_LANGS = ['en', 'zh', 'ar'];
const TRANSLATE_PROVIDER =
    process.env.TRANSLATE_PROVIDER || (process.env.AWS_ACCESS_KEY_ID ? 'aws' : 'mock');

const translateClient =
    TRANSLATE_PROVIDER === 'aws'
        ? new TranslateClient({ region: process.env.AWS_REGION || 'ap-northeast-2' })
        : null;

// 한 필드를 한 언어로 번역. 실패하거나 mock 모드면 [lang] 접두 폴백을 반환.
async function translateField(text, targetLang) {
    if (!text) return text;
    if (translateClient) {
        try {
            const out = await translateClient.send(new TranslateTextCommand({
                Text: text,
                SourceLanguageCode: SOURCE_LANG,
                TargetLanguageCode: targetLang,
            }));
            
            // [SRE 메트릭 추가] PM 쿼리 1: 번역 API 호출 성공 로그
            logger.info('translate_api_called', { target_lang: targetLang, provider: TRANSLATE_PROVIDER });
            
            return out.TranslatedText;
        } catch (err) {
            // [SRE 메트릭 추가] PM 쿼리 2: 번역 API 호출 실패 로그
            logger.error('translate_api_failed', { target_lang: targetLang, error_code: err.name, error_message: err.message });
            logger.error('AWS Translate failed, using fallback', { targetLang, error: err.message });
        }
    }
    // 로컬/실패 폴백: 번역 파이프라인이 동작함을 보이기 위한 표식 (운영에선 AWS 사용)
    return `[${targetLang}] ${text}`;
}

// 이벤트의 title/description 을 모든 대상 언어로 번역해 translations 행 배열로 반환.
async function buildTranslations(eventId, { title, description, location }) {
    const rows = [];
    for (const lang of TARGET_LANGS) {
        rows.push([eventId, 'title', lang, await translateField(title, lang)]);
        if (description) {
            rows.push([eventId, 'description', lang, await translateField(description, lang)]);
        }
        if (location) {
            rows.push([eventId, 'location', lang, await translateField(location, lang)]);
        }
    }
    return rows;
}

// [SRE 규칙 12] UUID 토큰 authMiddleware + 캐시 + DB 조회 (token + role)
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
        const [rows] = await pool.execute("SELECT id, role FROM users WHERE token = ?", [token]);
        if (rows.length === 0) return res.status(401).json({ error: 'Unauthorized', message: '로그인 필요' });

        const user = rows[0];
        authCache.set(token, { user, ts: now });
        req.user = user;
        next();
    } catch (err) {
        logger.error("Auth error", { error: err.message });
        res.status(500).json({ error: "Auth Error" });
    }
};

// [BACKEND_REVIEW #7] 관리자 전용 가드
const requireAdmin = (req, res, next) => {
    if (req.user?.role !== 'admin') {
        return res.status(403).json({ error: 'Forbidden', message: '관리자 권한이 필요합니다' });
    }
    next();
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

// 관리자 예약 처리


// 이벤트 등록
app.post('/admin/events', authMiddleware, requireAdmin, async (req, res) => {
    const { title, description, location, category, image_url, main_image_url, slots } = req.body;

    if (!title || !title.trim()) return res.status(400).json({ error: 'ValidationError', message: '제목(title)은 필수입니다' });
    if (!category || !category.trim()) return res.status(400).json({ error: 'ValidationError', message: '카테고리(category)는 필수입니다' });

    const conn = await pool.getConnection();
    let inTx = false;
    try {
        await conn.beginTransaction();
        inTx = true;

        const [evt] = await conn.execute(
            "INSERT INTO events (title, description, location, category, image_url, main_image_url) VALUES (?, ?, ?, ?, ?, ?)",
            [title, description ?? null, location ?? null, category, image_url ?? null, main_image_url ?? null]
        );
        const eventId = evt.insertId;

        const translationRows = await buildTranslations(eventId, { title, description, location });
        for (const row of translationRows) {
            await conn.execute(
                "INSERT INTO translations (event_id, field_name, target_lang, translated_text) VALUES (?, ?, ?, ?)",
                row
            );
        }

        let slotCount = 0;
        if (Array.isArray(slots)) {
            for (const s of slots) {
                if (!s?.slot_datetime || !s?.max_capacity) continue;
                await conn.execute(
                    "INSERT INTO event_slots (event_id, slot_datetime, remaining_capacity, max_capacity, version) VALUES (?, ?, ?, ?, 0)",
                    [eventId, s.slot_datetime, s.max_capacity, s.max_capacity]
                );
                slotCount += 1;
            }
        }

        await conn.commit();
        inTx = false;
        logger.info('Event created with translations', {
            eventId, provider: TRANSLATE_PROVIDER, langs: TARGET_LANGS, slots: slotCount
        });
        res.status(201).json({
            event_id: eventId,
            translated_langs: TARGET_LANGS,
            translation_provider: TRANSLATE_PROVIDER,
            slots_created: slotCount,
            message: '이벤트 등록 및 번역 완료',
        });
    } catch (err) {
        if (inTx) await conn.rollback();
        logger.error('Event create failed', { error: err.message });
        res.status(500).json({ error: 'Internal Server Error' });
    } finally {
        conn.release();
    }
});

const server = app.listen(PORT, '0.0.0.0', () => logger.info(`Admin Service on port ${PORT}`));

server.keepAliveTimeout = 75000;
server.headersTimeout = 80000;

process.on('SIGTERM', () => {
    logger.info("SIGTERM received. Shutting down...");
    server.close(async () => {
        await pool.end();
        process.exit(0);
    });
});