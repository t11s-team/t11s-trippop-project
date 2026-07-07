# 팀 규칙

## 작업 원칙

| 원칙 | 설명 |
| --- | --- |
| 작은 PR | PR 하나는 목적 하나만 가진다 |
| 오너십 존중 | 다른 서비스/모듈 변경은 오너에게 먼저 공유한다 |
| 실제 코드 기준 | 문서만 보지 않고 `main.js`, SQL, manifest, Terraform state를 함께 확인한다 |
| 민감값 금지 | password, PAT, DB secret, 개인 profile 값은 커밋하지 않는다 |
| 운영 영향 명시 | PR에 영향 범위와 검증 결과를 남긴다 |

## 네이밍

AWS:

```text
t11s-{env}-{resource}-{name}
```

예시:

```text
t11s-dev-vpc-cloud
t11s-dev-ecr-reservation-service
t11s-dev-eks
```

Git branch:

```text
feature/{area}-{desc}
fix/{area}-{desc}
infra/{module}-{desc}
docs/{topic}
```

Kubernetes:

| 종류 | 규칙 | 예시 |
| --- | --- | --- |
| Deployment | `{domain}-api` | `reservation-api` |
| Service | `{domain}-svc` | `reservation-svc` |
| HPA | `{domain}-hpa` | `reservation-hpa` |
| Namespace | 고정 | `trippop` |

## 버전

| 도구 | 기준 |
| --- | --- |
| Node.js | 22 |
| Docker base | `node:22-alpine` |
| Terraform | `>= 1.9.0` |
| AWS Provider | `~> 6.0` |
| EKS | 1.34 |
| MariaDB | 10.11 |

## 금지 사항

```text
DB를 Public에 노출
Admin EC2에서 애플리케이션 서비스 실행
Security Group을 불필요하게 0.0.0.0/0로 개방
Docker image tag latest 사용
예약 생성에서 트랜잭션 제거
사용자 입력을 SQL 문자열에 직접 삽입
Terraform apply를 임의 수행
```

## 서비스 변경 규칙

API 요청/응답을 바꿀 때:

```text
1. 서비스 오너에게 공유
2. 프론트 호출부 영향 확인
3. DB 스키마 영향 확인
4. 03-service-api-contracts.md 수정
5. PR에 curl 예시와 응답 예시 첨부
```

DB 스키마를 바꿀 때:

```text
1. 이창하 승인
2. scripts/db_init.sql 수정
3. seed/reset 영향 확인
4. 서비스 SQL 수정
5. 마이그레이션 또는 재초기화 절차 명시
```

Terraform을 바꿀 때:

```text
1. 모듈 오너 확인
2. fmt/validate 실행
3. target plan 결과 요약
4. DB/EBS destroy 또는 replace 여부 확인
5. apply 담당자에게 명령어와 plan 요약 전달
```

## 코드 규칙

Backend:

```text
Express
mysql2/promise Pool
JSON structured logging
GET /health/live
GET /health/ready
SIGTERM graceful shutdown
server.keepAliveTimeout = 75000
server.headersTimeout = 80000
```

Reservation:

```text
x-idempotency-key 필수
slot_id 필수
트랜잭션 필수
remaining_capacity 조건부 UPDATE 필수
idempotency_key UNIQUE 유지
UNIQUE(user_id, event_slot_id) 유지
```

Kubernetes:

```text
namespace는 trippop
ConfigMap/Secret은 envFrom으로 주입
Probe와 preStop은 모든 서비스에 유지
non-root/read-only root filesystem 보안 설정 유지
PDB와 topologySpreadConstraints 유지
admin-service와 Admin EC2를 혼동하지 않는다
```

## 책임 경계

| 변경 | 먼저 볼 사람 |
| --- | --- |
| API path/field | 서비스 오너 + 프론트 담당 |
| DB table/column/index | 이창하 |
| SG/Route/VPC/Peering | 이성호 + 이창하 |
| EKS/Ingress/HPA | 김건호 |
| CD/ECR/S3/CloudFront | 김채아 |
| 모니터링/알람/비용 | 성지수 |
