// ============================================================
// concurrent-spike.js — 동시 예약 경합 테스트
//
// 목표: 잔여 1개 슬롯에 100명이 동시에 예약 시도
// 기대: 1명만 201, 99명은 409 (오버부킹 0)
//
// 실행:
//   k6 run --env BASE_URL=https://api.trippop.store \
//          concurrent-spike.js
//   ※ SLOT_ID 는 "잔여 정확히 1석"인 슬롯을 가리켜야 한다(실행 직전 verify 필수).
//     db_seed.sql 의 동시성 전용 슬롯 id=901(잔여 1) → 기본값 901.
//     재실행 전 db_reset.sql 로 잔여 1·version 0 원복 후 돌릴 것.
//   ※ 경합자는 VU마다 서로 다른 유저여야 진짜 N-way 경합이 된다.
//     UNIQUE(user_id, slot_id) 때문에 같은 유저가 또 쏘면 정원 경합이 아니라
//     중복-유저 409로 빠진다. → db_seed.sql 의 distinct 유저
//     loadtest-token-0001~0100 을 VU당 1개씩 쓴다. 규모는 --env VU_COUNT 로 조절.
// ============================================================

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter } from 'k6/metrics';
function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// 커스텀 메트릭 (Grafana에서 시각화)
const successCount = new Counter('reservation_success');
const conflictCount = new Counter('reservation_conflict');
const otherErrorCount = new Counter('reservation_other_error');

// 경합 인원 = VU 수 = distinct 유저 수. 한 슬롯(901, 정원 1석)에 동시 진입.
const VU_COUNT = parseInt(__ENV.VU_COUNT || '100');

export const options = {
  scenarios: {
    spike: {
      executor: 'shared-iterations',
      vus: VU_COUNT,            // 100명 동시
      iterations: VU_COUNT,     // 각자 1회씩 (총 100회 요청)
      maxDuration: '60s',
    },
  },
  thresholds: {
    // 1명만 성공 (정원 1석)
    'reservation_success': ['count==1'],
    // 나머지 전원 매진 충돌
    'reservation_conflict': [`count==${VU_COUNT - 1}`],
  },
};

// db_seed.sql 의 부하 전용 distinct 유저 (loadtest-token-0001 ~ 1000).
// VU당 1개씩 배정 → VU 수만큼의 서로 다른 유저가 슬롯 901을 두고 진짜로 경합한다.
// (UUID 5토큰을 돌려쓰던 기존 방식은 distinct 5명뿐이라 15건이 중복-유저 409로 새던 문제를 해결)
const tokens = Array.from({ length: VU_COUNT }, (_, i) =>
  `loadtest-token-${String(i + 1).padStart(4, '0')}`
);

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:3001';
  const slotId = parseInt(__ENV.SLOT_ID || '901');

  // VU별로 서로 다른 distinct 유저 토큰 (VU N → loadtest-token-{N}).
  // 모두 첫 예약이라 실패는 정원 소진(매진 409)으로만 발생 → 진짜 N-way 정원 경합.
  const tokenIndex = (__VU - 1) % tokens.length;
  const token = tokens[tokenIndex];

  const payload = JSON.stringify({
    slot_id: slotId,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
      'x-idempotency-key': uuidv4(),  // 매 요청마다 새 UUID
    },
    tags: { name: 'reservation_post' },
  };

  const res = http.post(`${baseUrl}/reservations`, payload, params);

  // 결과 분류
  if (res.status === 201) {
    successCount.add(1);
    console.log(`V VU ${__VU}: 201 Created`);
  } else if (res.status === 409) {
    conflictCount.add(1);
    let errorMsg = 'unknown';
    try {
      errorMsg = JSON.parse(res.body).error;
    } catch (e) {}
    console.log(`!  VU ${__VU}: 409 - ${errorMsg}`);
  } else {
    otherErrorCount.add(1);
    console.log(`X VU ${__VU}: ${res.status} - ${res.body}`);
  }

  check(res, {
    'status is 201 or 409': (r) => r.status === 201 || r.status === 409,
  });
}

export function handleSummary(data) {
  const success = (data.metrics.reservation_success && data.metrics.reservation_success.values && data.metrics.reservation_success.values.count) || 0;
  const conflict = (data.metrics.reservation_conflict && data.metrics.reservation_conflict.values && data.metrics.reservation_conflict.values.count) || 0;
  const other = (data.metrics.reservation_other_error && data.metrics.reservation_other_error.values && data.metrics.reservation_other_error.values.count) || 0;

  console.log('\n========================================');
  console.log('  동시 예약 경합 테스트 결과');
  console.log('========================================');
  console.log(`  성공 (201): ${success}건`);
  console.log(`  충돌 (409): ${conflict}건`);
  console.log(`  기타 에러: ${other}건`);
  console.log(`  총 요청:    ${success + conflict + other}건`);
  console.log('----------------------------------------');

  if (success === 1 && conflict === VU_COUNT - 1 && other === 0) {
    console.log('  V PASS — 오버부킹 없음. 정합성 보장.');
  } else if (success > 1) {
    console.log('  X FAIL — 오버부킹 발생! 정합성 깨짐.');
  } else if (other > 0) {
    console.log('  !  WARN — 예상치 못한 에러 발생.');
  } else {
    console.log('  !  WARN — 결과 검토 필요.');
  }
  console.log('========================================\n');

  return {
    'summary.json': JSON.stringify(data, null, 2),
  };
}
