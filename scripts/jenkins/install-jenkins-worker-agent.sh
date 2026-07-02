#!/usr/bin/env bash
set -Eeuo pipefail

readonly AGENT_USER="jenkins-agent"
readonly AGENT_HOME="/var/lib/jenkins-agent"
readonly CONFIG_DIR="/etc/jenkins-agent"
readonly CONFIG_FILE="${CONFIG_DIR}/agent.env"
readonly SECRET_FILE="${CONFIG_DIR}/secret"
readonly LAUNCHER_FILE="/usr/local/sbin/jenkins-agent-launcher"
readonly SERVICE_FILE="/etc/systemd/system/jenkins-agent.service"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root (for example: sudo bash $0 <jenkins-url> <node-name>)." >&2
  exit 1
fi

if [[ "$#" -ne 2 ]]; then
  echo "Usage: sudo bash $0 http://<master-private-ip>:8080 <node-name>" >&2
  exit 1
fi

jenkins_url="${1%/}"
node_name="$2"

if [[ ! "${jenkins_url}" =~ ^https?://[^[:space:]]+$ ]]; then
  echo "Jenkins URL must start with http:// or https:// and contain no whitespace." >&2
  exit 1
fi

if [[ ! "${node_name}" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Node name may contain only letters, numbers, dots, underscores, and hyphens." >&2
  exit 1
fi

if [[ ! -t 0 ]]; then
  echo "An interactive terminal is required so the agent secret is not exposed in shell history." >&2
  exit 1
fi

read -r -s -p "Paste the Jenkins inbound-agent secret: " agent_secret
echo

if [[ ! "${agent_secret}" =~ ^[A-Za-z0-9]{32,256}$ ]]; then
  echo "The agent secret must be 32-256 alphanumeric characters." >&2
  exit 1
fi

echo "Installing the Jenkins Worker service prerequisites..."
dnf install -y java-21-amazon-corretto-headless

if ! command -v curl >/dev/null 2>&1; then
  dnf install -y curl-minimal
fi

if ! getent group docker >/dev/null 2>&1; then
  echo "Docker group is missing. Confirm Docker was installed by the Worker user-data script." >&2
  exit 1
fi

if ! id "${AGENT_USER}" >/dev/null 2>&1; then
  useradd \
    --system \
    --create-home \
    --home-dir "${AGENT_HOME}" \
    --shell /sbin/nologin \
    "${AGENT_USER}"
fi

usermod -aG docker "${AGENT_USER}"
install -d -m 0750 -o "${AGENT_USER}" -g "${AGENT_USER}" "${AGENT_HOME}"
install -d -m 0750 -o root -g "${AGENT_USER}" "${CONFIG_DIR}"

cat >"${CONFIG_FILE}" <<EOF
JENKINS_URL=${jenkins_url}
JENKINS_AGENT_NAME=${node_name}
JENKINS_AGENT_WORKDIR=${AGENT_HOME}
EOF
chown root:"${AGENT_USER}" "${CONFIG_FILE}"
chmod 0640 "${CONFIG_FILE}"

umask 0077
printf '%s\n' "${agent_secret}" >"${SECRET_FILE}"
chown "${AGENT_USER}":"${AGENT_USER}" "${SECRET_FILE}"
chmod 0400 "${SECRET_FILE}"
unset agent_secret

cat >"${LAUNCHER_FILE}" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

readonly CONFIG_FILE="/etc/jenkins-agent/agent.env"
readonly SECRET_FILE="/etc/jenkins-agent/secret"

# shellcheck disable=SC1091
source "${CONFIG_FILE}"

readonly AGENT_JAR="${JENKINS_AGENT_WORKDIR}/agent.jar"
temporary_jar="$(mktemp "${JENKINS_AGENT_WORKDIR}/agent.jar.XXXXXX")"
trap 'rm -f "${temporary_jar}"' EXIT

curl \
  --fail \
  --location \
  --retry 5 \
  --retry-delay 3 \
  --silent \
  --show-error \
  --output "${temporary_jar}" \
  "${JENKINS_URL}/jnlpJars/agent.jar"

mv -f "${temporary_jar}" "${AGENT_JAR}"
trap - EXIT

exec /usr/bin/java \
  -jar "${AGENT_JAR}" \
  -url "${JENKINS_URL}" \
  -secret "@${SECRET_FILE}" \
  -name "${JENKINS_AGENT_NAME}" \
  -webSocket \
  -workDir "${JENKINS_AGENT_WORKDIR}"
EOF
chown root:root "${LAUNCHER_FILE}"
chmod 0755 "${LAUNCHER_FILE}"

cat >"${SERVICE_FILE}" <<'EOF'
[Unit]
Description=TripPlanner Jenkins inbound Worker agent
Wants=network-online.target
After=network-online.target docker.service
Requires=docker.service

[Service]
Type=simple
User=jenkins-agent
Group=jenkins-agent
SupplementaryGroups=docker
ExecStart=/usr/local/sbin/jenkins-agent-launcher
Restart=always
RestartSec=10
TimeoutStopSec=30
KillSignal=SIGTERM
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=full
ReadWritePaths=/var/lib/jenkins-agent

[Install]
WantedBy=multi-user.target
EOF
chown root:root "${SERVICE_FILE}"
chmod 0644 "${SERVICE_FILE}"

systemctl daemon-reload
systemctl enable --now jenkins-agent

sleep 3
if ! systemctl is-active --quiet jenkins-agent; then
  echo "The agent service is not active. Inspect: journalctl -u jenkins-agent --no-pager -n 200" >&2
  exit 1
fi

echo
echo "Jenkins Worker service is active and enabled at boot."
echo "Service check: systemctl status jenkins-agent --no-pager"
echo "Connection log: journalctl -u jenkins-agent --no-pager -n 100"
