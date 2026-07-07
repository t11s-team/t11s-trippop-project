# Kubernetes/CD 가이드

## Kubernetes 기준

| 항목 | 기준 |
| --- | --- |
| Cluster | EKS 1.34 |
| Namespace | `trippop` |
| Ingress | AWS Load Balancer Controller |
| Ingress name | `k-culture-integrated-ingress` |
| API host | `<api-domain>` |
| DB Secret | `kculture-db-secrets` |
| ConfigMap | `kculture-config` |

## Manifest 구조

```text
k8s/base/
├─ namespace.yaml
├─ configmap.yaml
├─ secret.example.yaml
├─ reservation-base.yaml
├─ event-base.yaml
├─ user-base.yaml
├─ admin-base.yaml
├─ integrated-ingress.yaml
├─ servicemonitor.yaml
├─ prometheusrules.yaml
├─ grafana-dashboards/
└─ kustomization.yaml
```

모든 서비스는 아래를 포함한다.

```text
Deployment
Service
envFrom ConfigMap + Secret
livenessProbe /health/live
readinessProbe /health/ready
startupProbe /health/live
preStop sleep 30
non-root, read-only root filesystem
resource requests/limits
PodDisruptionBudget
topologySpreadConstraints
```

reservation-service만 HPA를 사용한다.

```text
minReplicas: 2
maxReplicas: 10
CPU averageUtilization: 70%
```

## 서비스/Ingress 매핑

| 외부 path | Service | Port | Deployment |
| --- | --- | ---: | --- |
| `/reservations` | `reservation-svc` | 3001 | `reservation-api` |
| `/events` | `event-svc` | 3002 | `event-api` |
| `/users` | `user-svc` | 3003 | `user-api` |
| 내부/운영 | `admin-svc` | 3004 | `admin-api` |

현재 `integrated-ingress.yaml`에는 admin-service 외부 path가 없다. 외부 노출이 필요하면 서비스 오너와 보안 담당자의 승인을 받은 뒤 Ingress path를 추가한다.

## ConfigMap/Secret

ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kculture-config
  namespace: trippop
data:
  DB_PORT: "3306"
  CORS_ORIGIN: "FRONTEND_ORIGIN_PLACEHOLDER"
```

Secret key:

```yaml
DB_HOST: "<db-private-address>"
DB_USER: "<db-user>"
DB_PASSWORD: "..."
DB_NAME: "kculture"
```

실제 Secret 값은 Git에 커밋하지 않는다. `k8s/base/secret.example.yaml`은 필요한 key를 보여주는 샘플이다.

## CD 흐름

GitHub Actions CD는 다음 순서로 동작한다.

```text
1. 서비스별 Docker image build
2. ECR push
3. kubeconfig 설정
4. kustomize image tag를 Git SHA로 갱신
5. Kubernetes DB Secret 적용
6. kubectl apply -k k8s/base
7. Route 53 `<api-domain>` CNAME 갱신
8. rollout status 확인
9. frontend build artifact를 S3/CloudFront에 배포
```

Route 53 갱신은 `scripts/update-api-route53-record.sh`가 담당한다.

필요한 GitHub Secret 또는 Repository Variable:

```text
AWS_ACCOUNT_ID
ECR_REGISTRY
AWS_ROLE_ARN
S3_FRONTEND_BUCKET
CLOUDFRONT_DISTRIBUTION_ID
ROUTE53_HOSTED_ZONE_ID
API_DOMAIN_NAME
FRONTEND_DOMAIN_NAME
API_ACM_CERTIFICATE_ARN
```

CD workflow에서는 Git에 커밋된 placeholder manifest를 배포 직전에 GitHub Secrets 값으로 렌더링한다.

placeholder 예:

```text
ECR_REGISTRY_PLACEHOLDER
API_DOMAIN_NAME_PLACEHOLDER
API_ACM_CERTIFICATE_ARN_PLACEHOLDER
FRONTEND_ORIGIN_PLACEHOLDER
```

`scripts/sync-github-actions-secrets.sh`를 사용하면 Terraform output과 로컬 tfvars 값을 GitHub Secrets로 동기화할 수 있다.

## 이미지 태그 규칙

`latest`를 사용하지 않는다. CD는 Git SHA를 tag로 쓴다.

```text
<ecr-registry>/t11s-dev-ecr-event-service:{github.sha}
```

`k8s/base/kustomization.yaml`의 `tmp-sha`는 CD가 실제 Git SHA로 치환하기 전 배포를 막는 guard 값이다.

## EKS Add-ons와 모니터링

Terraform/Helm으로 다음 구성 요소를 관리한다.

```text
AWS Load Balancer Controller
Metrics Server
AWS EBS CSI Driver
Cluster Autoscaler
kube-prometheus-stack
Fluent Bit
```

- EBS CSI Driver는 Prometheus, Grafana, Alertmanager PVC용 gp3 볼륨을 동적 생성한다.
- Cluster Autoscaler는 HPA로 늘어난 Pod가 Pending일 때 Managed Node Group을 확장한다.
- ServiceMonitor는 4개 앱 Service의 `/metrics`를 수집한다.
- DB EC2 exporter는 Prometheus `additionalScrapeConfigs`로 수집한다.

## 배포 검증

```bash
kubectl get nodes
kubectl get pods -A
kubectl get deploy,svc,ingress -n trippop
kubectl rollout status deployment/event-api -n trippop --timeout=300s
kubectl rollout status deployment/reservation-api -n trippop --timeout=300s
kubectl rollout status deployment/user-api -n trippop --timeout=300s
kubectl rollout status deployment/admin-api -n trippop --timeout=300s
```

Ingress/ALB:

```bash
kubectl get ingress k-culture-integrated-ingress \
  -n trippop \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Route 53:

```bash
dig <api-domain> CNAME +short
```

API:

```bash
curl -vk https://<api-domain>/events
```

## ALB 삭제 순서

EKS destroy 전에 Ingress를 먼저 삭제한다.

```bash
kubectl delete ingress k-culture-integrated-ingress \
  -n trippop \
  --wait=true \
  --timeout=10m
```

이 단계를 건너뛰고 AWS Load Balancer Controller를 먼저 삭제하면 ALB/Target Group이 고아 리소스로 남을 수 있다.

## 자주 나는 오류

### Namespace not found

```text
Error from server (NotFound): namespaces "trippop" not found
```

해결:

```bash
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -k k8s/base
```

### ImagePullBackOff

확인:

```bash
kubectl describe pod -n trippop <pod>
kubectl get secret -n trippop
aws ecr describe-images --repository-name t11s-dev-ecr-event-service
```

주요 원인:

```text
ECR image tag 없음
CD가 kustomization image를 잘못 갱신
Node role/ECR pull 권한 문제
```

### Express 404

예:

```text
Cannot GET /events/health/live
```

의미:

```text
DNS/ALB/Ingress는 통과했고 Express 앱까지 도달했다.
서비스에 해당 route가 없거나 Ingress prefix와 Express route가 맞지 않는다.
```
