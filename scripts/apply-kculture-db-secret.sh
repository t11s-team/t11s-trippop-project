#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-northeast-2}"
K8S_NAMESPACE="${K8S_NAMESPACE:-trippop}"
K8S_SECRET_NAME="${K8S_SECRET_NAME:-kculture-db-secrets}"
K8S_DB_PASSWORD_SECRET_ID="${K8S_DB_PASSWORD_SECRET_ID:-t11s-dev-db-app-password}"

DB_HOST="${DB_HOST:-172.16.10.122}"
DB_USER="${DB_USER:-admin}"
DB_NAME="${DB_NAME:-kculture}"

command -v kubectl >/dev/null || { echo "[ERROR] kubectl이 필요합니다."; exit 1; }

if [[ -n "${DB_PASSWORD:-}" ]]; then
  DB_PASSWORD_SOURCE="DB_PASSWORD"
elif [[ -n "${TF_VAR_ec2_db_app_password:-}" ]]; then
  DB_PASSWORD="${TF_VAR_ec2_db_app_password}"
  DB_PASSWORD_SOURCE="TF_VAR_ec2_db_app_password"
else
  command -v aws >/dev/null || { echo "[ERROR] aws CLI가 필요합니다."; exit 1; }
  DB_PASSWORD="$(
    aws secretsmanager get-secret-value \
      --region "${AWS_REGION}" \
      --secret-id "${K8S_DB_PASSWORD_SECRET_ID}" \
      --query SecretString \
      --output text
  )"
  DB_PASSWORD_SOURCE="Secrets Manager:${K8S_DB_PASSWORD_SECRET_ID}"
fi

if [[ -z "${DB_PASSWORD}" || "${DB_PASSWORD}" == "None" ]]; then
  echo "[ERROR] DB password를 읽지 못했습니다."
  exit 1
fi

kubectl create secret generic "${K8S_SECRET_NAME}" \
  --namespace "${K8S_NAMESPACE}" \
  --from-literal=DB_HOST="${DB_HOST}" \
  --from-literal=DB_USER="${DB_USER}" \
  --from-literal=DB_PASSWORD="${DB_PASSWORD}" \
  --from-literal=DB_NAME="${DB_NAME}" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

echo "[INFO] Kubernetes Secret applied: ${K8S_NAMESPACE}/${K8S_SECRET_NAME}"
echo "[INFO] DB_HOST=${DB_HOST}, DB_USER=${DB_USER}, DB_NAME=${DB_NAME}"
echo "[INFO] DB_PASSWORD source=${DB_PASSWORD_SOURCE}"
