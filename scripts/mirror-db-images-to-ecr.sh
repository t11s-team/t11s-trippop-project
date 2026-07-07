#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:=ap-northeast-2}"
: "${MARIADB_SOURCE_IMAGE:=mariadb:10.11}"
: "${NODE_EXPORTER_SOURCE_IMAGE:=quay.io/prometheus/node-exporter:v1.8.2}"
: "${MYSQLD_EXPORTER_SOURCE_IMAGE:=prom/mysqld-exporter:v0.15.1}"

required_vars=(
  MARIADB_TARGET_IMAGE
  NODE_EXPORTER_TARGET_IMAGE
  MYSQLD_EXPORTER_TARGET_IMAGE
)

for name in "${required_vars[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "[ERROR] ${name} is required." >&2
    exit 1
  fi
done

command -v aws >/dev/null || { echo "[ERROR] aws CLI is required." >&2; exit 1; }
command -v docker >/dev/null || { echo "[ERROR] docker is required." >&2; exit 1; }

mirror_image() {
  local source_image="$1"
  local target_image="$2"
  local registry
  local repo_with_tag
  local repository
  local tag

  registry="$(printf '%s' "${target_image}" | cut -d/ -f1)"
  repo_with_tag="${target_image#${registry}/}"
  repository="${repo_with_tag%:*}"
  tag="${repo_with_tag##*:}"

  if aws ecr describe-images \
    --region "${AWS_REGION}" \
    --repository-name "${repository}" \
    --image-ids imageTag="${tag}" >/dev/null 2>&1; then
    echo "[INFO] ${target_image} already exists. Skipping."
    return 0
  fi

  echo "[INFO] Login to ${registry}"
  aws ecr get-login-password --region "${AWS_REGION}" |
    docker login --username AWS --password-stdin "${registry}" >/dev/null

  echo "[INFO] Mirror ${source_image} -> ${target_image}"
  docker pull "${source_image}"
  docker tag "${source_image}" "${target_image}"
  docker push "${target_image}"
}

mirror_image "${MARIADB_SOURCE_IMAGE}" "${MARIADB_TARGET_IMAGE}"
mirror_image "${NODE_EXPORTER_SOURCE_IMAGE}" "${NODE_EXPORTER_TARGET_IMAGE}"
mirror_image "${MYSQLD_EXPORTER_SOURCE_IMAGE}" "${MYSQLD_EXPORTER_TARGET_IMAGE}"

echo "[INFO] DB runtime image mirror completed."
