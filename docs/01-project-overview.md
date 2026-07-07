# 프로젝트 개요

## 한 줄 요약

trippop은 외국인 관광객이 K-컬처 팝업스토어 이벤트를 조회하고 예약할 수 있는 MSA 기반 예약 플랫폼이다.

## 해결하려는 문제

외국인 관광객은 한국 팝업스토어와 문화 체험에 관심이 높지만, 실제 방문 전에는 다음 문제를 겪는다.

```text
언어 장벽
예약 가능 시간 확인 어려움
현장 대기 비용
관리자 입장에서 이벤트/슬롯/예약 관리 도구 부족
```

trippop은 이 문제를 "이벤트 조회 -> 슬롯 선택 -> 예약 생성 -> 관리자 운영" 흐름으로 좁혀 풀었다.

## 핵심 설계

| 설계 | 선택 |
| --- | --- |
| 애플리케이션 | EKS 기반 4개 마이크로서비스 |
| DB | On-Prem Simulation VPC의 EC2 + Docker MariaDB |
| 네트워크 | Cloud VPC와 On-Prem VPC를 VPC Peering으로 연결 |
| 외부 진입 | Route 53 + ALB Ingress |
| 프론트 배포 | S3/CloudFront |
| 예약 정합성 | 트랜잭션, 멱등성 키, 낙관적 잠금, DB UNIQUE |
| 운영 | GitHub Actions CD, Terraform 모듈화, 비용 절감 절차 |

## 아키텍처

```text
Internet
  |
Route 53 / CloudFront / ALB
  |
Cloud VPC (10.0.0.0/16)
  ├─ Public Subnet
  │  ├─ ALB
  │  └─ NAT Gateway
  └─ Private App Subnet
     └─ EKS Worker Nodes
        ├─ reservation-service
        ├─ event-service
        ├─ user-service
        └─ admin-service

VPC Peering

On-Prem Simulation VPC (172.16.0.0/16)
  ├─ Public Subnet
  │  └─ Admin EC2 (SSM 기반 베스천)
  └─ Private DB Subnet
     └─ DB EC2 (Docker MariaDB 10.11)
```

## 서비스 구성

| 서비스 | 포트 | 외부 path | 책임 |
| --- | ---: | --- | --- |
| reservation-service | 3001 | `/reservations` | 예약 생성/조회, 동시성 제어 |
| event-service | 3002 | `/events` | 이벤트 목록/상세/슬롯 조회 |
| user-service | 3003 | `/users` | 회원가입, 로그인, token 인증 |
| admin-service | 3004 | 내부/운영 | 이벤트/슬롯 등록, 번역 |

## 팀 역할

| 담당 | 역할 | 책임 |
| --- | --- | --- |
| 성지수 | PM + 모니터링/비용/운영 | 일정, 리뷰, 대시보드, 운영 가시성 |
| 이성호 | 네트워크 인프라 + TF Release | VPC, Peering, SG, Terraform 통합, apply |
| 이창하 | DB + 보안 | MariaDB, 스키마, Secrets, IAM/보안 |
| 김채아 | CI/CD + 프론트 전달 | GitHub Actions, ECR/S3/CloudFront, UI 전달 |
| 김건호 | EKS + reservation | EKS 운영, HPA, reservation-service |
| 김재백 | user/event/admin + 다국어 | user-service, event-service, admin-service, Translate, E2E |

## 주요 데모 포인트

| 데모 | 성공 기준 |
| --- | --- |
| 정상 예약 | 회원가입/로그인 후 이벤트 슬롯 예약 성공 |
| 동시성 | 잔여 좌석 1개에 다중 요청 시 1명만 성공 |
| HPA | reservation Pod가 부하에 따라 확장 |
| 앱 계층 고가용성 | Pod 장애 후 readiness/liveness로 자동 복구 |
| 하이브리드 네트워크 | EKS Pod가 Peering 경유로 Private DB에 접근 |
| 운영 | Route 53, ALB, CD, 모니터링, 비용 종료 절차 확인 |

## 현재 한계와 로드맵

| 한계 | 이유 | 보완 방향 |
| --- | --- | --- |
| DB는 단일 EC2 | 자체 운영 DB 학습과 비용 제약 | replication/standby/failover 검토 |
| Ingress prefix rewrite 미적용 | AWS ALB Controller 특성 | 백엔드 prefix route 정렬 또는 별도 gateway 검토 |
| 일부 운영 자동화는 개인 환경 의존 | 학습 프로젝트 범위 | 팀 공용 runbook 또는 pipeline 단계로 이관 |

## 주요 경로

```text
services/*/main.js
scripts/db_init.sql
k8s/base/
infra/envs/team-dev/
infra/modules/
.github/workflows/
```
