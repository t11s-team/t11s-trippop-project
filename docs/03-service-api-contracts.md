# 서비스/API/DB 계약

이 문서는 프론트엔드와 백엔드, 서비스 오너가 함께 지켜야 하는 계약이다. API를 바꿀 때는 코드만 바꾸지 말고 이 문서, DB 스키마, 프론트 호출부를 함께 수정한다.

## 서비스 오너

| 영역 | 오너 | 백업/협업 | 코드 |
| --- | --- | --- | --- |
| reservation-service | 김건호 | 이창하(DB 정합성), 이성호(EKS/네트워크) | `services/reservation-service/` |
| event-service | 김재백 | 이창하(DB), 김채아/성지수(프론트 호출) | `services/event-service/` |
| user-service | 김재백 | 이창하(DB/보안), 김채아/성지수(프론트 호출) | `services/user-service/` |
| admin-service | 김재백 | 이창하(DB/보안), 이성호(운영 접근) | `services/admin-service/` |
| DB 스키마/Secrets | 이창하 | 이성호(apply), 서비스 오너 | `scripts/db_init.sql`, `scripts/db_seed.sql` |
| API 변경 승인 | 성지수(PM) | 서비스 오너 | 이 문서와 PR |

## 공통 API 규칙

| 항목 | 규칙 |
| --- | --- |
| Base host | `https://<api-domain>` |
| Namespace/Ingress | `trippop`, `k-culture-integrated-ingress` |
| 인증 | `Authorization: Bearer {token}` |
| 예약 멱등성 | `x-idempotency-key: {uuid}` |
| Content-Type | `application/json` |
| Health | 모든 서비스 `GET /health/live`, `GET /health/ready` |
| Metrics | 모든 서비스 `GET /metrics` |
| DB client | `mysql2/promise` Pool |
| SQL | 사용자 입력은 반드시 parameterized query |

ALB Ingress는 path prefix를 제거하지 않는다. 예를 들어 `/events/health/live` 요청은 event-service에 그대로 `/events/health/live`로 전달된다. 서비스 health를 외부에서 직접 확인할 때는 Ingress path와 Express route가 맞는지 먼저 확인한다.

인증 토큰은 JWT가 아니라 DB `users.token` 컬럼에 저장되는 UUID token이다. 로그인할 때 token을 회전하고, 각 서비스의 인증 캐시는 60초 TTL을 사용한다.

## Frontend 계약

프론트엔드는 아래 필드명을 기준으로 호출한다. 필드명을 바꾸면 반드시 프론트 담당자에게 먼저 공유한다.

### 회원가입

```http
POST /users/signup/request
Content-Type: application/json
```

Request:

```json
{
  "email": "user@example.com",
  "name": "Alex",
  "password": "password123",
  "language": "en"
}
```

Response `201`:

```json
{
  "token": "uuid-token",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "Alex",
    "language": "en",
    "role": "user"
  }
}
```

오류:

| 상황 | Status | 응답 |
| --- | ---: | --- |
| 이메일 형식 오류 | 400 | `ValidationError` |
| 비밀번호 8자 미만 | 400 | `ValidationError` |
| 중복 이메일 | 409 | `Conflict` |

### 로그인

```http
POST /users/signin
Content-Type: application/json
```

Request:

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

Response `200`:

```json
{
  "token": "rotated-uuid-token",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "Alex",
    "language": "en",
    "role": "user"
  }
}
```

### 현재 사용자

```http
GET /users/me
Authorization: Bearer {token}
```

Response `200`:

```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "Alex",
    "language": "en",
    "role": "user"
  }
}
```

### 이벤트 목록

```http
GET /events?lang=en
```

Response `200`:

```json
[
  {
    "id": 1,
    "location": "Seoul",
    "category": "popup",
    "image_url": "https://...",
    "description": "Korean source description",
    "title": "Translated title",
    "slots_left": 10,
    "next_slot": "2026-06-01T10:00:00.000Z"
  }
]
```

### 이벤트 상세

```http
GET /events/{event_id}?lang=en
```

Response `200`:

```json
{
  "id": 1,
  "category": "popup",
  "image_url": "https://...",
  "location": "Seoul",
  "title": "Translated title",
  "description": "Translated description",
  "slots": [
    {
      "id": 3,
      "slot_datetime": "2026-06-01T10:00:00.000Z",
      "max_capacity": 20,
      "remaining_capacity": 5,
      "version": 7
    }
  ]
}
```

### 예약 생성

```http
POST /reservations
Authorization: Bearer {token}
x-idempotency-key: {uuid}
Content-Type: application/json
```

Request:

```json
{
  "slot_id": 3
}
```

Response `201`:

```json
{
  "reservation_id": 10,
  "slot_id": 3,
  "status": "confirmed",
  "message": "Reservation confirmed"
}
```

멱등성 재시도 Response `200`:

```json
{
  "reservation_id": 10,
  "slot_id": 3,
  "status": "confirmed",
  "idempotent": true,
  "message": "이미 처리된 요청입니다 (기존 예약 반환)"
}
```

예약 오류:

| 상황 | Status | 의미 |
| --- | ---: | --- |
| 토큰 없음/무효 | 401 | 로그인 필요 |
| `x-idempotency-key` 없음 | 400 | 멱등성 키 필수 |
| `slot_id` 없음 | 400 | 슬롯 ID 필수 |
| 슬롯 없음 | 404 | 존재하지 않는 슬롯 |
| 매진 | 409 | 마감되었습니다 |
| 동일 사용자의 동일 슬롯 재예약 | 409 | 이미 예약하셨습니다 |
| 낙관락 재시도 소진 | 409 | 다시 시도해주세요 |

### 내 예약 목록

```http
GET /reservations
Authorization: Bearer {token}
```

Response `200`:

```json
[
  {
    "id": 10,
    "status": "confirmed",
    "created_at": "2026-05-29T10:00:00.000Z",
    "event_slot_id": 3,
    "slot_datetime": "2026-06-01T10:00:00.000Z",
    "event_id": 1,
    "event_title": "K-pop Popup",
    "event_image": "https://...",
    "location": "Seoul"
  }
]
```

### 관리자 이벤트 생성

```http
POST /admin/events
Authorization: Bearer {admin-token}
Content-Type: application/json
```

Request:

```json
{
  "title": "K-pop Popup",
  "description": "한국어 설명",
  "location": "Seoul",
  "category": "popup",
  "image_url": "https://...",
  "slots": [
    {
      "slot_datetime": "2026-06-01 10:00:00",
      "max_capacity": 20
    }
  ]
}
```

Response `201`:

```json
{
  "event_id": 1,
  "translated_langs": ["en", "ja", "zh"],
  "translation_provider": "aws",
  "slots_created": 1,
  "message": "이벤트 등록 및 번역 완료"
}
```

## DB 스키마 핵심

기준 파일은 `scripts/db_init.sql`이다.

| 테이블 | 핵심 컬럼/제약 |
| --- | --- |
| `users` | `email UNIQUE`, `password_hash`, `role`, `token UNIQUE` |
| `events` | `title`, `description`, `location`, `category`, `image_url` |
| `event_slots` | `remaining_capacity CHECK >= 0`, `max_capacity`, `version` |
| `reservations` | `idempotency_key UNIQUE`, `UNIQUE(user_id, event_slot_id)` |
| `translations` | `UNIQUE(event_id, field_name, target_lang)` |

예약 정합성은 애플리케이션과 DB가 함께 보장한다.

```text
1. idempotency_key 사전 조회
2. remaining_capacity/version 조회
3. 조건부 UPDATE로 잔여 좌석 차감
4. reservations INSERT
5. UNIQUE 제약으로 중복 요청 최종 방어
6. 전체 과정을 단일 트랜잭션으로 처리
```

## 환경 변수

| 이름 | 사용처 | 설명 |
| --- | --- | --- |
| `DB_HOST` | 모든 서비스 | DB EC2 Private IP 또는 DNS |
| `DB_PORT` | 모든 서비스 | `3306` |
| `DB_USER` | 모든 서비스 | DB 계정 |
| `DB_PASSWORD` | 모든 서비스 | Kubernetes Secret에서 주입 |
| `DB_NAME` | 모든 서비스 | `kculture` |
| `DB_CONN_LIMIT` | 모든 서비스 | Pool connection 수 |
| `CORS_ORIGIN` | 모든 서비스 | 허용할 프론트 origin, 콤마 구분 |
| `TRANSLATE_PROVIDER` | admin-service | `aws` 또는 `mock` |
| `AWS_REGION` | admin-service | `ap-northeast-2` |

민감값은 Git에 커밋하지 않는다. Kubernetes Secret은 `scripts/apply-kculture-db-secret.sh`나 팀에서 합의한 Secret 관리 절차로 생성한다.

## 관리자 서비스 노출 범위

`admin-service`는 EKS에 Deployment/Service로 배포되지만 현재 ALB Ingress 외부 path는 없다. 외부 관리자 API가 필요하면 인증과 네트워크 노출 범위를 먼저 검토한 뒤 Ingress를 추가한다.
