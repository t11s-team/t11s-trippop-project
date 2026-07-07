// ============================================================
// reservation-load.js — 점진 부하 테스트 (HPA 데모용)
//
// 목표: 실제 RPS를 점진 증가 → reservation-service Pod가 2 → N으로 스케일아웃
//
// 부하 패턴 (ramping-arrival-rate, 초당 요청 수를 직접 목표):
//   0~2분:   50 → 200 req/s
//   2~5분:   200 → 600 req/s
//   5~8분:   600 → 1200 req/s       ← HPA 트리거 + 한계 탐색 (목표 8 pod)
//   8~10분:  1200 req/s 유지         ← Pod 스케일아웃 확인
//   10~12분: → 50 req/s (cooldown)
//
//   ※ ramping-vus + sleep 방식은 VU당 0.5 req/s로 처리량이 묶여
//     CPU가 문턱(50%)에 도달하지 못했음. arrival-rate로 RPS를 직접 보장한다.
//
// 실행:
//   k6 run --env BASE_URL=https://api.trippop.store reservation-load.js
//   (슬롯은 부하 전용 920~943, 유저는 loadtest-token-0001~6000 무작위 — env 불필요)
//   규모 조절: --env TOKEN_COUNT=3000
//   ※ TOKEN_COUNT 는 DB에 실제 시드된 loadtest-token-* 유저 수(6000)를 넘으면 안 된다.
//     초과분 토큰은 users 테이블에 없어 전부 401(로그인 필요)로 떨어져 테스트가 무효가 된다.
//     db_seed.sql 의 user_generator(n<6000)와 항상 일치시킬 것.
// ============================================================

import http from 'k6/http';
import { check } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';
function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

const successCount = new Counter('reservation_success');
const conflictCount = new Counter('reservation_conflict');
const errorRate = new Rate('error_rate');
const reservationDuration = new Trend('reservation_duration_ms');

export const options = {
  scenarios: {
    ramping_load: {
      executor: 'ramping-arrival-rate',
      startRate: 50,            // 초당 50건으로 시작
      timeUnit: '1s',
      preAllocatedVUs: 400,     // 시작 시 미리 확보하는 VU 풀
      maxVUs: 2000,             // 1200 rps에서 지연이 늘어도 VU가 부족해지지 않도록 상향
      stages: [
        // 부하 증가 시작
        { duration: '2m', target: 200 },   // → 200 req/s
        { duration: '3m', target: 600 },   // → 600 req/s
        // HPA 트리거 + 한계 탐색 구간 (목표 8 pod)
        { duration: '3m', target: 1200 },  // → 1200 req/s
        // 유지 (Pod 스케일아웃 확인)
        { duration: '2m', target: 1200 },
        // cooldown
        { duration: '2m', target: 50 },
      ],
    },
  },
  thresholds: {
    // p95 응답 시간 2초 미만
    'http_req_duration': ['p(95)<2000'],
    // 에러율 5% 미만 (5xx만 카운트, 409 충돌은 정상)
    'error_rate': ['rate<0.05'],
  },
};

// db_seed.sql 의 부하 전용 유저 (loadtest-token-0001 ~ N).
// 기본값 6000 = 현재 db_seed.sql 이 시드하는 유저 수(user_generator n<6000). 이 값을 실제
// 시드 수보다 크게 잡으면 없는 토큰이 401 로 쏟아지니 db_seed.sql 과 항상 일치시킬 것.
// 유저 수 = 쓰기 부하 상한(UNIQUE(user_id,slot)). 6000이면 조합(6,000×24=144,000)이
// 슬롯 정원(24×5,000=120,000)을 넘겨, 1200 rps 피크에서도 ~100초간 201 insert 가 지속되며
// 후반에 "마감(sold out)" 409 가 일부 찍힌다(HPA 가 8 pod 까지 반응할 시간 확보).
const TOKEN_COUNT = parseInt(__ENV.TOKEN_COUNT || '6000');
const tokens = Array.from({ length: TOKEN_COUNT }, (_, i) =>
  `loadtest-token-${String(i + 1).padStart(4, '0')}`
);

// 부하 전용 대용량 슬롯 920~943 (각 cap 5000 = 총 120,000, db_seed.sql).
// 의도적으로 후반 피크(~8분)에 정원이 소진되며 sold-out 409가 일부 찍히도록 상향.
const slotIds = Array.from({ length: 24 }, (_, i) => 920 + i);

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:3001';

  // 토큰 + 슬롯 무작위 분배
  const token = tokens[Math.floor(Math.random() * tokens.length)];
  const slotId = slotIds[Math.floor(Math.random() * slotIds.length)];

  const payload = JSON.stringify({
    slot_id: slotId,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
      'x-idempotency-key': uuidv4(),
    },
    tags: { name: 'reservation_post' },
  };

  const startTime = Date.now();
  const res = http.post(`${baseUrl}/reservations`, payload, params);
  const duration = Date.now() - startTime;

  reservationDuration.add(duration);

  // 결과 분류
  if (res.status === 201) {
    successCount.add(1);
    errorRate.add(false);
  } else if (res.status === 409) {
    conflictCount.add(1);
    errorRate.add(false);  // 409는 정상 비즈니스 응답
  } else {
    errorRate.add(true);  // 5xx만 에러로 카운트
    console.log(`X VU ${__VU}: ${res.status} - ${res.body.substring(0, 100)}`);
  }

  check(res, {
    'status is 2xx or 409': (r) =>
      (r.status >= 200 && r.status < 300) || r.status === 409,
    'response time < 2s': (r) => r.timings.duration < 2000,
  });

  // arrival-rate 방식에서는 sleep 금지 — k6가 도착률(RPS)을 직접 제어하므로
  // 여기서 대기하면 VU가 묶여 목표 RPS를 못 채운다.
}

export function handleSummary(data) {
  const success = (data.metrics.reservation_success && data.metrics.reservation_success.values && data.metrics.reservation_success.values.count) || 0;
  const conflict = (data.metrics.reservation_conflict && data.metrics.reservation_conflict.values && data.metrics.reservation_conflict.values.count) || 0;
  const totalReqs = (data.metrics.http_reqs && data.metrics.http_reqs.values && data.metrics.http_reqs.values.count) || 0;
  const p95 = (data.metrics.http_req_duration && data.metrics.http_req_duration.values && data.metrics.http_req_duration.values['p(95)']) || 0;
  const errRate = ((data.metrics.error_rate && data.metrics.error_rate.values && data.metrics.error_rate.values.rate) || 0) * 100;

  console.log('\n========================================');
  console.log('  점진 부하 테스트 결과 (HPA 데모)');
  console.log('========================================');
  console.log(`  총 요청:    ${totalReqs}건`);
  console.log(`  성공 (201): ${success}건`);
  console.log(`  충돌 (409): ${conflict}건`);
  console.log(`  p95 응답:   ${p95.toFixed(0)}ms`);
  console.log(`  에러율:     ${errRate.toFixed(2)}%`);
  console.log('----------------------------------------');

  if (p95 < 2000 && errRate < 5) {
    console.log('  V PASS — 임계치 내 안정 동작');
  } else if (p95 >= 2000) {
    console.log('  !  WARN — p95 응답 시간 초과');
  }
  if (errRate >= 5) {
    console.log('  X FAIL — 에러율 5% 초과');
  }
  console.log('========================================');
  console.log('\n 다음 확인 명령어:');
  console.log('  kubectl get hpa -n trippop');
  console.log('  kubectl get pods -n trippop -l app=reservation');
  console.log('  → Pod 수가 2에서 늘어났는지 확인');
  console.log('========================================\n');

  return {
    'summary.json': JSON.stringify(data, null, 2),
  };
}
