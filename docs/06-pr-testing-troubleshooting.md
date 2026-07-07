# PR/테스트/트러블슈팅

## 브랜치와 커밋

브랜치:

```text
feature/{area}-{desc}
fix/{area}-{desc}
infra/{module}-{desc}
docs/{topic}
```

커밋:

```text
{type}: {summary}
```

예시:

```text
feat: add route53 api record update
fix: align event route with ingress path
infra: add eks addon helm release
docs: update api contract
```

## PR 본문 템플릿

```md
## 변경 요약
- 

## 변경 이유

## 영향 범위
- Frontend:
- Backend:
- DB:
- Infra:
- Kubernetes:
- CI/CD:

## 검증
- [ ] 로컬 테스트
- [ ] terraform fmt/validate/plan
- [ ] kubectl apply/rollout
- [ ] API curl

## 롤백

## 담당자 확인
- 서비스 오너:
- 모듈 오너:
- apply 담당:
```

## API 변경 PR 체크리스트

```text
1. 서비스 오너 승인
2. 프론트 호출부 영향 확인
3. 요청/응답 필드명 문서 수정
4. 상태 코드와 오류 메시지 문서 수정
5. DB 컬럼/인덱스 영향 확인
6. curl 예시 추가
```

## Terraform PR 체크리스트

```text
1. 모듈 오너 확인
2. 변수/outputs 추가 여부 확인
3. team-dev main.tf 연결 확인
4. fmt/validate 통과
5. target plan 결과 요약
6. DB/EBS destroy 또는 replace 없음 확인
7. SG/IAM 권한 확대는 승인자 명시
```

## 로컬 테스트

서비스 문법:

```bash
cd services/reservation-service
npm ci
npm test
```

현재 저장소에는 공용 Docker Compose 실행 파일이 있다. 로컬 DB와 서비스 컨테이너를 함께 띄울 때는 아래 명령을 사용한다.

```bash
docker compose --profile local up --build
```

서비스 변경을 정적으로 검증할 때는 개별 Node.js 문법 검사와 Docker image build 결과를 함께 확인한다.

주의:

```text
서비스 package.json의 npm test는 현재 node --check main.js 중심이다.
통합 테스트나 실제 DB 동작 검증을 대신하지 않는다.
```

Frontend:

```bash
cd frontend
npm ci
npm run lint
npm run build
```

Kubernetes 정적 렌더링:

```bash
kubectl kustomize k8s/base
```

## DB 확인

```sql
USE kculture;
SHOW TABLES;
DESCRIBE users;
DESCRIBE events;
DESCRIBE event_slots;
DESCRIBE reservations;
DESCRIBE translations;
```

예약 상태:

```sql
SELECT id, event_id, slot_datetime, remaining_capacity, max_capacity, version
FROM event_slots
ORDER BY id;

SELECT id, user_id, event_slot_id, status, idempotency_key, created_at
FROM reservations
ORDER BY id DESC
LIMIT 20;
```

## API 수동 테스트

회원가입:

```bash
curl -s -X POST https://<api-domain>/users/signup/request \
  -H 'Content-Type: application/json' \
  -d '{"email":"user@example.com","name":"Alex","password":"password123","language":"en"}'
```

이벤트:

```bash
curl -s 'https://<api-domain>/events?lang=en'
curl -s 'https://<api-domain>/events/1?lang=en'
```

예약:

```bash
curl -s -X POST https://<api-domain>/reservations \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-idempotency-key: $(uuidgen)" \
  -H 'Content-Type: application/json' \
  -d '{"slot_id":3}'
```

## Kubernetes 점검

```bash
kubectl get pods -n trippop
kubectl describe pod -n trippop <pod>
kubectl logs -n trippop deploy/reservation-api
kubectl get endpoints -n trippop reservation-svc
kubectl describe ingress -n trippop k-culture-integrated-ingress
kubectl get hpa -n trippop
kubectl get pdb -n trippop
kubectl get servicemonitor -n trippop
```

## AWS 점검

EKS:

```bash
aws eks describe-cluster \
  --region ap-northeast-2 \
  --name t11s-dev-eks \
  --query "cluster.{name:name,status:status,endpoint:endpoint}" \
  --output table
```

NAT:

```bash
aws ec2 describe-nat-gateways \
  --region ap-northeast-2 \
  --filter "Name=tag:Name,Values=t11s-dev-nat-cloud-single,t11s-dev-nat-onprem-temp" \
  --query 'NatGateways[].{name:Tags[?Key==`Name`]|[0].Value,id:NatGatewayId,state:State,subnet:SubnetId}' \
  --output table
```

ALB/TG:

```bash
aws elbv2 describe-load-balancers \
  --region ap-northeast-2 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-`)].{name:LoadBalancerName,dns:DNSName,state:State.Code}' \
  --output table

aws elbv2 describe-target-groups \
  --region ap-northeast-2 \
  --query 'TargetGroups[?contains(TargetGroupName, `k8s-`)].{name:TargetGroupName,port:Port}' \
  --output table
```

Route 53:

```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id "$ROUTE53_HOSTED_ZONE_ID" \
  --query "ResourceRecordSets[?Name == '<api-domain>.']"

dig <api-domain> CNAME +short
```

## 장애 해석 빠른 기준

| 증상 | 의미 | 담당 |
| --- | --- | --- |
| `Could not resolve host` | Route 53/DNS 문제 | 인프라/CD |
| ALB 404, `server: awselb/2.0` | Ingress rule 미매칭 | EKS/Ingress |
| Express 404, `Cannot GET ...` | 백엔드 route 미구현 또는 prefix 불일치 | 서비스 오너 |
| `ImagePullBackOff` | ECR tag/권한/imagePull 문제 | CI/CD + EKS |
| `CrashLoopBackOff` | 앱 실행 오류/env 누락 | 서비스 오너 |
| `DB Not Ready` | DB 연결/Secret/SG/Peering 문제 | DB + 인프라 |
| NodeGroup 생성 지연 | NAT/ECR/STS 접근 문제 가능 | 인프라 + EKS |
| PVC Pending | EBS CSI Driver/StorageClass/IRSA 문제 | EKS/인프라 |
| HPA 증가 후 Pod Pending | Node 용량 부족 또는 Cluster Autoscaler 문제 | EKS |
| DB exporter down | DB EC2 exporter/SG/Peering 문제 | DB + 인프라 |

## 예약 동시성 검증

기대 결과:

```text
잔여 좌석 1개에 20명 동시 요청
-> 1명 201
-> 나머지 409
-> event_slots.remaining_capacity = 0
-> reservations는 1건만 생성
```

확인 SQL:

```sql
SELECT remaining_capacity, version
FROM event_slots
WHERE id = 3;

SELECT COUNT(*)
FROM reservations
WHERE event_slot_id = 3
  AND status = 'confirmed';

SHOW INDEX FROM reservations;
```
