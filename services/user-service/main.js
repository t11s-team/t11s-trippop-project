require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');

const promClient = require('prom-client');

// ============================================================
// Prometheus 메트릭 계측 (관측 추가 — 로직 변경 없음)
// ============================================================
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register, prefix: 'user_' });

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
// [포트 규칙] user-service: 3003
const PORT = process.env.PORT || 3003;

// [SRE 4] JSON Structured Logging
const logger = {
    info: (msg, extra = {}) => console.log(JSON.stringify({
        timestamp: new Date().toISOString(), level: 'INFO', service: 'user-svc', message: msg, ...extra
    })),
    error: (msg, extra = {}) => console.error(JSON.stringify({
        timestamp: new Date().toISOString(), level: 'ERROR', service: 'user-svc', message: msg, ...extra
    }))
};

// [SRE 3 / BACKEND_REVIEW #10] CORS: 쉼표로 여러 origin 허용, 미설정 시 로컬 dev origin 기본값.
// (origin 을 undefined 로 두면 cors 가 모든 origin 을 허용하므로 절대 그렇게 두지 않는다)
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

// [SRE 1, 2] 환경변수 DB 접속 (USER: admin)
const pool = mysql.createPool({
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER,      // admin
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,  // kculture
    connectionLimit: parseInt(process.env.DB_CONN_LIMIT) || 3,
    charset: 'utf8mb4' // 한글/아랍어 등 멀티바이트 mojibake 방지 (커넥션을 utf8mb4로 고정)
});

const BCRYPT_ROUNDS = 10;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// [BACKEND_REVIEW #11] 서버측 입력 검증 (클라이언트를 신뢰하지 않는다)
function validateSignup({ email, name, password }) {
    if (!email || !EMAIL_RE.test(email)) return '유효한 이메일을 입력하세요';
    if (!name || !name.trim()) return '이름을 입력하세요';
    if (!password || password.length < 8) return '비밀번호는 8자 이상이어야 합니다';
    return null;
}

// [SRE 12] UUID 토큰 authMiddleware + 캐시 + DB 조회
// [M5] 토큰 회전 시 구 토큰이 캐시에 남아있는 노출 창을 줄이기 위해 TTL을 60초로 둔다.
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
        // [규칙] verify_token -> token 컬럼 조회
        const [rows] = await pool.execute(
            "SELECT id, email, name, language, role FROM users WHERE token = ?", [token]
        );
        // [BACKEND_REVIEW #15] 유효하지 않은 토큰 = 401 (서비스 간 일관)
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
// [SRE 5] Health Check
app.get('/health/live', (req, res) => res.status(200).send('OK'));
app.get('/health/ready', async (req, res) => {
    try { await pool.query('SELECT 1'); res.status(200).send('Ready'); }
    catch (err) { res.status(503).send('Database connection failed'); }
});

// [BACKEND_REVIEW #2, #3] 회원가입: 비밀번호 해싱 + 토큰 발급 후 즉시 반환 (가입 = 로그인 상태)
app.post('/users/signup/request', async (req, res) => {
    const { email, name, password } = req.body;
    const language = req.body.language || 'en'; // [#4] 미전달 시 기본값

    const invalid = validateSignup({ email, name, password });
    if (invalid) return res.status(400).json({ error: 'ValidationError', message: invalid });

    try {
        const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
        const token = uuidv4();
        const [result] = await pool.execute(
            "INSERT INTO users (email, name, password_hash, language, token) VALUES (?, ?, ?, ?, ?)",
            [email, name, passwordHash, language, token]
        );
        const user = { id: result.insertId, email, name, language, role: 'user' };
        logger.info("Signup success", { userId: user.id, email });
        // 201 Created + 토큰 반환 → 프론트엔드가 즉시 인증 상태로 진입 가능
        res.status(201).json({ token, user });
    } catch (err) {
        // [BACKEND_REVIEW #22] 이메일 UNIQUE 위반은 친절한 409 로 매핑
        if (err.code === 'ER_DUP_ENTRY') {
            return res.status(409).json({ error: 'Conflict', message: '이미 가입된 이메일입니다' });
        }
        logger.error("Signup failed", { error: err.message });
        res.status(500).json({ error: "Internal Server Error" });
    }
});

// [BACKEND_REVIEW #1] 로그인: 비밀번호 검증 후 토큰 회전 발급
app.post('/users/signin', async (req, res) => {
    const { email, password } = req.body;
    if (!email || !password) {
        return res.status(400).json({ error: 'ValidationError', message: '이메일과 비밀번호를 입력하세요' });
    }
    try {
        const [rows] = await pool.execute(
            "SELECT id, email, name, language, role, password_hash FROM users WHERE email = ?",
            [email]
        );
        // 사용자 없음/비밀번호 불일치는 동일 메시지로 (계정 존재 여부 노출 방지)
        const fail = () =>
            res.status(401).json({ error: 'Unauthorized', message: '이메일 또는 비밀번호가 올바르지 않습니다' });

        if (rows.length === 0) return fail();
        const u = rows[0];
        if (!u.password_hash) return fail();
        const ok = await bcrypt.compare(password, u.password_hash);
        if (!ok) return fail();

        // 로그인 시 토큰 회전 → 이전 세션 무효화
        const token = uuidv4();
        await pool.execute("UPDATE users SET token = ? WHERE id = ?", [token, u.id]);
        logger.info("Signin success", { userId: u.id });
        res.json({
            token,
            user: { id: u.id, email: u.email, name: u.name, language: u.language, role: u.role }
        });
    } catch (err) {
        logger.error("Signin failed", { error: err.message });
        res.status(500).json({ error: "Internal Server Error" });
    }
});

// 토큰 검증/현재 사용자 조회 (프론트 부팅 시 세션 확인용)
app.get('/users/me', authMiddleware, (req, res) => {
    res.json({ user: req.user });
});

const server = app.listen(PORT, '0.0.0.0', () => {
    logger.info(`User Service started on port ${PORT}`);
});

// [SRE 10, 11] ALB Timeout 설정
server.keepAliveTimeout = 75000;
server.headersTimeout = 80000;

// [SRE 8] SIGTERM graceful shutdown
process.on('SIGTERM', () => {
    logger.info("SIGTERM received. Closing server...");
    server.close(async () => {
        await pool.end();
        process.exit(0);
    });
});
