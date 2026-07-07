#!/usr/bin/env bash
# ============================================================
# bootstrap-cluster.sh
# EKS 클러스터 전체 K8s 리소스를 한 번에 적용
# 사용법: bash scripts/bootstrap-cluster.sh
# 실행 순서: Helm 스택 설치 후 (install-helm-stack.sh 다음)
# 멱등성: 모든 apply는 dry-run=false 지원, 재실행 안전
# ============================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-northeast-2}"
CLUSTER_NAME="${CLUSTER_NAME:-t11s-dev-eks}"
APP_NS="trippop"
MONITORING_NS="monitoring"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
section() { echo -e "\n${GREEN}════════════════════════════════════${NC}"; \
            echo -e "${GREEN} $*${NC}"; \
            echo -e "${GREEN}════════════════════════════════════${NC}"; }

# ── 사전 확인 ─────────────────────────────────────────────
section "사전 확인"
command -v kubectl >/dev/null || error "kubectl이 필요합니다."
command -v aws     >/dev/null || error "aws CLI가 필요합니다."

aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
kubectl cluster-info --request-timeout=5s || error "EKS 클러스터에 연결할 수 없습니다."

# Helm 스택이 설치되어 있는지 확인
if ! helm status kube-prometheus-stack -n "$MONITORING_NS" >/dev/null 2>&1; then
  error "kube-prometheus-stack이 설치되지 않았습니다. 먼저 install-helm-stack.sh를 실행하세요."
fi
info "사전 확인 완료"

# ── Step 1. namespace ─────────────────────────────────────
section "Step 1. namespace 생성"
kubectl apply -f k8s/base/namespace.yaml
info "namespace/$APP_NS 준비 완료"

# ── Step 2. ConfigMap ─────────────────────────────────────
section "Step 2. ConfigMap 적용"
kubectl apply -f k8s/base/configmap.yaml
info "ConfigMap (CORS_ORIGIN=CloudFront) 적용 완료"

# ── Step 3. DB Secret ─────────────────────────────────────
section "Step 3. DB Secret 적용"
bash scripts/apply-kculture-db-secret.sh
info "kculture-db-secrets 적용 완료"

# ── Step 4. 앱 매니페스트 (kustomize) ─────────────────────
section "Step 4. 앱 매니페스트 적용 (kustomize)"
kubectl apply -k k8s/base
info "앱 매니페스트 적용 완료"

# ── Step 5. PrometheusRule ────────────────────────────────
# kustomization.yaml에 포함 안 됨 (monitoring ns 분리). 별도 적용.
section "Step 5. PrometheusRule 적용"
kubectl apply -f k8s/base/prometheusrules.yaml
info "PrometheusRule (trippop-alerts, 12개) 적용 완료"

# 이전 버전 default ns 룰 정리
if kubectl get prometheusrule kculture-must-rules -n default >/dev/null 2>&1; then
  warn "옛 PrometheusRule (default ns) 발견 → 삭제"
  kubectl delete prometheusrule kculture-must-rules -n default
fi

# ── Step 6. Route53 갱신 ──────────────────────────────────
section "Step 6. Route53 API 레코드 갱신"
if [[ -n "${ROUTE53_HOSTED_ZONE_ID:-}" ]]; then
  bash scripts/update-api-route53-record.sh
  info "Route53 갱신 완료"
else
  warn "ROUTE53_HOSTED_ZONE_ID 환경변수 없음 → Route53 갱신 스킵"
  warn "필요시 수동 실행: ROUTE53_HOSTED_ZONE_ID=<id> bash scripts/update-api-route53-record.sh"
fi

# ── Step 7. 롤아웃 대기 ───────────────────────────────────
section "Step 7. 롤아웃 대기 (최대 5분)"
DEPLOYMENTS=(reservation-api event-api user-api admin-api)
for dep in "${DEPLOYMENTS[@]}"; do
  if kubectl get deployment "$dep" -n "$APP_NS" >/dev/null 2>&1; then
    info "대기 중: $dep"
    kubectl rollout status deployment/"$dep" -n "$APP_NS" --timeout=300s \
      && info "$dep 롤아웃 완료 ✅" \
      || warn "$dep 롤아웃 타임아웃 (확인 필요)"
  else
    warn "$dep 아직 없음 (CD 트리거 후 생성될 예정)"
  fi
done

# ── Step 8. 검증 ──────────────────────────────────────────
section "Step 8. 상태 검증"

echo ""
echo "── Pod 상태 ──────────────────────────"
kubectl get pods -n "$APP_NS" 2>/dev/null || warn "trippop ns 아직 없음"

echo ""
echo "── Prometheus targets (port-forward 필요) ──"
echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo "  → http://localhost:9090/targets"

echo ""
echo "── 알람 등록 확인 ──────────────────────"
PROM_READY=$(kubectl get pods -n "$MONITORING_NS" \
  -l app.kubernetes.io/name=prometheus \
  -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
if [[ "$PROM_READY" == "true" ]]; then
  RULE_COUNT=$(kubectl port-forward -n "$MONITORING_NS" \
    svc/kube-prometheus-stack-prometheus 9090:9090 &>/dev/null & \
    sleep 2 && \
    curl -s http://localhost:9090/api/v1/rules 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); \
    rules=[r for g in d.get('data',{}).get('groups',[]) \
           if g['name'].startswith('trippop') \
           for r in g['rules']]; print(len(rules))" 2>/dev/null || echo "확인 불가")
  kill %1 2>/dev/null || true
  info "trippop 알람 등록 수: $RULE_COUNT (기대값: 12)"
else
  warn "Prometheus 아직 준비 안 됨. 나중에 수동 확인."
fi

echo ""
echo "── CORS_ORIGIN 확인 ──────────────────"
CORS=$(kubectl get configmap kculture-config -n "$APP_NS" \
  -o jsonpath='{.data.CORS_ORIGIN}' 2>/dev/null || echo "확인 불가")
if echo "$CORS" | grep -q "cloudfront"; then
  info "CORS_ORIGIN: $CORS ✅"
else
  warn "CORS_ORIGIN: $CORS ← CloudFront 아님! configmap.yaml 확인 필요"
fi

# ── 완료 요약 ──────────────────────────────────────────────
section "bootstrap-cluster.sh 완료"
echo ""
echo "  적용된 항목:"
echo "  ✅ namespace/trippop"
echo "  ✅ ConfigMap (CORS_ORIGIN=CloudFront)"
echo "  ✅ kculture-db-secrets"
echo "  ✅ 앱 매니페스트 (kustomize)"
echo "  ✅ PrometheusRule (trippop-alerts)"
echo ""
echo "  이미지 배포는 CD 트리거(git push) 후 자동."
echo "  DB EC2 exporter 동작 중인지 확인:"
echo "    aws ssm start-session --target i-05a2ae24528c61f1a"
echo "    sudo docker ps | grep -E 'node-exporter|mysqld-exporter'"
echo ""
echo "  Grafana 접속:"
echo "    kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo "    → http://localhost:3000"