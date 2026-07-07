#!/usr/bin/env bash
# ============================================================
# install-helm-stack.sh
# EKS 클러스터에 Helm 스택 전체를 설치
# 사용법: bash scripts/install-helm-stack.sh
# 멱등성: 이미 설치된 경우 upgrade로 처리
# ============================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-northeast-2}"
CLUSTER_NAME="${CLUSTER_NAME:-t11s-dev-eks}"
MONITORING_NS="monitoring"
SLACK_WEBHOOK_SECRET="${SLACK_WEBHOOK_SECRET:-}"

# ── 색상 출력 ──────────────────────────────────────────────
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
command -v helm    >/dev/null || error "helm이 필요합니다."
command -v aws     >/dev/null || error "aws CLI가 필요합니다."

# kubeconfig 갱신
info "kubeconfig 갱신..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
kubectl cluster-info --request-timeout=5s || error "EKS 클러스터에 연결할 수 없습니다."
info "클러스터 연결 확인 완료"

# ── Step 1. Helm repo 추가 ─────────────────────────────────
section "Step 1. Helm repo 추가 및 업데이트"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update
info "Helm repo 업데이트 완료"

# ── Step 2. monitoring namespace ──────────────────────────
section "Step 2. monitoring namespace 생성"
kubectl create namespace "$MONITORING_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/base/namespace.yaml
info "namespace/$MONITORING_NS 준비 완료"

# ── Step 2.5. gp3 기본 StorageClass ────────────────────────
# monitoring-values.yaml의 PVC(prometheus/alertmanager/grafana)가
# storageClassName: gp3 을 참조하므로 helm install 전에 존재해야 한다.
# aws-ebs-csi-driver addon(terraform eks-addons) 선행 필요.
section "Step 2.5. gp3 기본 StorageClass"
kubectl apply -f k8s/storageclass-gp3.yaml
kubectl patch storageclass gp2 \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' \
  2>/dev/null || warn "gp2 StorageClass 없음 — 스킵"
info "gp3 StorageClass 적용 완료 (gp2 default 해제)"

# ── Step 3. Alertmanager Slack webhook Secret ──────────────
section "Step 3. Alertmanager Slack webhook Secret"

# Slack webhook URL 확보 (우선순위: 환경변수 > Secrets Manager > 수동 입력)
if [[ -n "${SLACK_WEBHOOK_SECRET}" ]]; then
  SLACK_URL="${SLACK_WEBHOOK_SECRET}"
  info "Slack webhook URL: 환경변수에서 읽음"
elif aws secretsmanager describe-secret \
      --region "$AWS_REGION" \
      --secret-id "t11s-dev-slack-webhook" \
      --query "Name" --output text >/dev/null 2>&1; then
  SLACK_URL="$(aws secretsmanager get-secret-value \
    --region "$AWS_REGION" \
    --secret-id "t11s-dev-slack-webhook" \
    --query SecretString --output text)"
  info "Slack webhook URL: Secrets Manager에서 읽음"
else
  warn "Slack webhook URL을 찾을 수 없습니다."
  warn "환경변수 SLACK_WEBHOOK_SECRET에 URL을 설정하거나 나중에 수동으로 Secret을 만드세요."
  warn "Alertmanager가 webhook 없이 설치되며, 알람 Slack 전송이 안 됩니다."
  SLACK_URL="https://hooks.slack.com/services/PLACEHOLDER"
fi

kubectl create secret generic alertmanager-slack-webhook \
  --namespace "$MONITORING_NS" \
  --from-literal=url="$SLACK_URL" \
  --dry-run=client -o yaml | kubectl apply -f -
info "Secret alertmanager-slack-webhook 적용 완료"

# ── Step 4. Grafana 대시보드 ConfigMap 적용 ───────────────
# 레거시 모델 JSON을 grafana_dashboard=1 라벨 ConfigMap으로 감싼다.
# Grafana sidecar가 이 라벨을 감지해 자동 임포트하므로 별도 API import는 없다.
section "Step 4. Grafana 대시보드 ConfigMap 적용"
kubectl apply -k k8s/base/grafana-dashboards
kubectl get configmap \
  -n trippop \
  -l grafana_dashboard=1
info "Grafana 대시보드 ConfigMap 적용 완료"

# ── Step 5. kube-prometheus-stack 설치/업그레이드 ──────────
section "Step 5. kube-prometheus-stack 설치/업그레이드"

HELM_CHART_VERSION="86.1.1"

if helm status kube-prometheus-stack -n "$MONITORING_NS" >/dev/null 2>&1; then
  info "기존 설치 감지 → helm upgrade 실행"
  # --reuse-values 제거: 이게 있으면 monitoring-values.yaml 변경(storageSpec,
  # retention, Slack 템플릿 등)이 조용히 무시된다. 항상 --values 로 전체 명시.
  helm upgrade kube-prometheus-stack \
    prometheus-community/kube-prometheus-stack \
    --namespace "$MONITORING_NS" \
    --version "$HELM_CHART_VERSION" \
    --values helm/monitoring-values.yaml \
    --timeout 10m \
    --atomic \
    --cleanup-on-fail \
    --wait
else
  info "신규 설치 → helm install 실행"
  helm install kube-prometheus-stack \
    prometheus-community/kube-prometheus-stack \
    --namespace "$MONITORING_NS" \
    --version "$HELM_CHART_VERSION" \
    --values helm/monitoring-values.yaml \
    --timeout 10m \
    --atomic \
    --wait
fi
info "kube-prometheus-stack 설치/업그레이드 완료 (버전: $HELM_CHART_VERSION)"

# 대시보드는 Step 4의 grafana_dashboard=1 ConfigMap을 sidecar가 자동 로드한다.
# (예전의 API import 단계는 제거됨 — 파드 재시작/재구축 시 자동 복구되지 않았음)

# ── Step 6. PrometheusRule 적용 ───────────────────────────
section "Step 6. PrometheusRule (알람 12개) 적용"
kubectl apply -f k8s/base/prometheusrules.yaml

# 검증
RULE_COUNT=$(kubectl get prometheusrule trippop-alerts -n "$MONITORING_NS" \
  -o jsonpath='{.spec.groups}' 2>/dev/null | python3 -c \
  "import sys,json; groups=json.load(sys.stdin); print(sum(len(g['rules']) for g in groups))" \
  2>/dev/null || echo "unknown")
info "PrometheusRule 적용 완료 (알람 수: $RULE_COUNT)"

# ── Step 7. Grafana sidecar 확인 ──────────────────────────
section "Step 7. Grafana sidecar 확인"
GRAFANA_POD=$(kubectl get pod -n "$MONITORING_NS" \
  -l app.kubernetes.io/name=grafana \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$GRAFANA_POD" ]]; then
  CONTAINERS=$(kubectl get pod -n "$MONITORING_NS" "$GRAFANA_POD" \
    -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || echo "")
  if echo "$CONTAINERS" | grep -q "grafana-sc-dashboard"; then
    info "Grafana sidecar 활성화 확인 ✅"
  else
    warn "Grafana sidecar 미확인. monitoring-values.yaml의 sidecar 설정 점검 필요."
  fi
else
  warn "Grafana Pod 아직 미기동. 잠시 후 수동 확인 필요."
fi

# ── 완료 요약 ──────────────────────────────────────────────
section "install-helm-stack.sh 완료"
echo ""
echo "  설치된 항목:"
echo "  ✅ kube-prometheus-stack v${HELM_CHART_VERSION}"
echo "  ✅ alertmanager-slack-webhook Secret"
echo "  ✅ PrometheusRule (trippop-alerts)"
echo "  ✅ Grafana sidecar"
echo ""
echo "  다음 단계: bash scripts/bootstrap-cluster.sh"
echo ""
echo "  Grafana 접속:"
echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo "  → http://localhost:3000 (admin / kubectl get secret ... 로 확인)"
