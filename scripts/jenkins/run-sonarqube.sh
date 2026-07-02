#!/usr/bin/env bash
set -Eeuo pipefail

readonly SONARQUBE_IMAGE="sonarqube:26.6.0.123539-community"
readonly SONARQUBE_CONTAINER="sonarqube"
readonly SONARQUBE_STATUS_URL="http://127.0.0.1:9000/api/system/status"
readonly SONARQUBE_CONFIG_DIR="/etc/sonarqube"
readonly SONARQUBE_ENV_FILE="${SONARQUBE_CONFIG_DIR}/sonar.env"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root (for example: sudo bash $0)." >&2
  exit 1
fi

if ! systemctl is-active --quiet docker; then
  echo "Docker is not active. Confirm Docker was installed by the Master user-data script." >&2
  exit 1
fi

echo "Applying the Linux settings required by SonarQube Elasticsearch..."
cat >/etc/sysctl.d/99-sonarqube.conf <<'EOF'
vm.max_map_count=524288
fs.file-max=131072
EOF
sysctl --system >/dev/null

echo "Creating persistent SonarQube volumes..."
for volume in sonarqube_data sonarqube_extensions sonarqube_logs; do
  docker volume create "${volume}" >/dev/null
done

install -d -m 0700 -o root -g root "${SONARQUBE_CONFIG_DIR}"
if [[ ! -s "${SONARQUBE_ENV_FILE}" ]]; then
  umask 0077
  jwt_secret="$(head -c 64 /dev/urandom | base64 --wrap=0)"
  printf 'SONAR_AUTH_JWTBASE64HS256SECRET=%s\n' "${jwt_secret}" >"${SONARQUBE_ENV_FILE}"
  unset jwt_secret
fi
chown root:root "${SONARQUBE_ENV_FILE}"
chmod 0600 "${SONARQUBE_ENV_FILE}"

echo "Pulling ${SONARQUBE_IMAGE}..."
docker pull "${SONARQUBE_IMAGE}"

if docker container inspect "${SONARQUBE_CONTAINER}" >/dev/null 2>&1; then
  echo "Replacing the existing SonarQube container while preserving its volumes..."
  docker rm --force "${SONARQUBE_CONTAINER}" >/dev/null
fi

docker run \
  --detach \
  --name "${SONARQUBE_CONTAINER}" \
  --restart unless-stopped \
  --publish 9000:9000 \
  --env-file "${SONARQUBE_ENV_FILE}" \
  --memory 4g \
  --memory-reservation 2g \
  --ulimit nofile=131072:131072 \
  --ulimit nproc=8192:8192 \
  --volume sonarqube_data:/opt/sonarqube/data \
  --volume sonarqube_extensions:/opt/sonarqube/extensions \
  --volume sonarqube_logs:/opt/sonarqube/logs \
  "${SONARQUBE_IMAGE}" >/dev/null

echo "Waiting for SonarQube to report status UP..."
status=""
for _ in {1..120}; do
  status="$(
    curl --fail --silent --show-error "${SONARQUBE_STATUS_URL}" 2>/dev/null \
      | jq -r '.status // empty' \
      || true
  )"

  if [[ "${status}" == "UP" ]]; then
    break
  fi

  if [[ "$(docker inspect --format '{{.State.Running}}' "${SONARQUBE_CONTAINER}" 2>/dev/null || true)" != "true" ]]; then
    break
  fi

  sleep 3
done

if [[ "${status}" != "UP" ]]; then
  echo "SonarQube did not become ready. Recent container logs follow:" >&2
  docker logs --tail 200 "${SONARQUBE_CONTAINER}" >&2 || true
  exit 1
fi

echo
echo "SonarQube is UP at port 9000 and will restart with Docker."
echo "Container check: docker ps --filter name=sonarqube"
echo "Log check: docker logs --tail 100 sonarqube"
