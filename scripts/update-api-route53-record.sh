#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin"

HOSTED_ZONE_ID="${ROUTE53_HOSTED_ZONE_ID:-}"
ROUTE53_UPDATE_REQUIRED="${ROUTE53_UPDATE_REQUIRED:-false}"
RECORD_NAME="${API_RECORD_NAME:-}"
K8S_NAMESPACE="${K8S_NAMESPACE:-trippop}"
INGRESS_NAME="${INGRESS_NAME:-k-culture-integrated-ingress}"
TTL="${ROUTE53_RECORD_TTL:-60}"
MAX_WAIT_SECONDS="${ROUTE53_ALB_DNS_MAX_WAIT_SECONDS:-300}"
SLEEP_SECONDS="${ROUTE53_ALB_DNS_POLL_SECONDS:-10}"

command -v aws >/dev/null || { echo "[ERROR] aws CLI가 필요합니다."; exit 1; }
command -v kubectl >/dev/null || { echo "[ERROR] kubectl이 필요합니다."; exit 1; }

if [[ -z "${RECORD_NAME}" ]]; then
  echo "[ERROR] API_RECORD_NAME이 없어 Route53 API 레코드를 갱신할 수 없습니다."
  exit 1
fi

if [[ -z "${HOSTED_ZONE_ID}" ]]; then
  if [[ "${ROUTE53_UPDATE_REQUIRED}" == "true" ]]; then
    echo "[ERROR] ROUTE53_HOSTED_ZONE_ID가 없어 Route53 업데이트를 진행할 수 없습니다."
    echo "[ERROR] GitHub Actions Secret 또는 Variable에 ROUTE53_HOSTED_ZONE_ID를 등록하세요."
    exit 1
  fi

  echo "[INFO] ROUTE53_HOSTED_ZONE_ID가 없어 Route53 업데이트를 건너뜁니다."
  exit 0
fi

elapsed=0
alb_dns=""

while [[ "${elapsed}" -le "${MAX_WAIT_SECONDS}" ]]; do
  alb_dns="$(
    kubectl get ingress "${INGRESS_NAME}" \
      -n "${K8S_NAMESPACE}" \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true
  )"

  if [[ -n "${alb_dns}" ]]; then
    break
  fi

  echo "[INFO] ALB DNS 대기 중: ${elapsed}/${MAX_WAIT_SECONDS}s"
  sleep "${SLEEP_SECONDS}"
  elapsed=$((elapsed + SLEEP_SECONDS))
done

if [[ -z "${alb_dns}" ]]; then
  echo "[ERROR] ${K8S_NAMESPACE}/${INGRESS_NAME}에서 ALB DNS를 찾지 못했습니다."
  exit 1
fi

change_batch="$(
  cat <<JSON
{
  "Comment": "Update ${RECORD_NAME} to current ALB DNS",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${RECORD_NAME}",
        "Type": "CNAME",
        "TTL": ${TTL},
        "ResourceRecords": [
          {
            "Value": "${alb_dns}"
          }
        ]
      }
    }
  ]
}
JSON
)"

aws route53 change-resource-record-sets \
  --hosted-zone-id "${HOSTED_ZONE_ID}" \
  --change-batch "${change_batch}"

echo "[INFO] Route53 updated: ${RECORD_NAME} -> ${alb_dns}"
