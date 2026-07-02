#!/usr/bin/env bash
set -Eeuo pipefail

readonly JENKINS_REPO_URL="https://pkg.jenkins.io/rpm-stable/jenkins.repo"
readonly JENKINS_REPO_FILE="/etc/yum.repos.d/jenkins.repo"
readonly JENKINS_URL="http://127.0.0.1:8080/login"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root (for example: sudo bash $0)." >&2
  exit 1
fi

echo "Installing Jenkins LTS prerequisites..."
dnf install -y \
  fontconfig \
  java-21-amazon-corretto-headless \
  wget

echo "Configuring the official Jenkins LTS RPM repository..."
wget -qO "${JENKINS_REPO_FILE}" "${JENKINS_REPO_URL}"

echo "Installing Jenkins..."
dnf install -y jenkins

systemctl daemon-reload
systemctl enable --now jenkins

echo "Waiting for Jenkins to answer on port 8080..."
for _ in {1..60}; do
  if curl --fail --silent --show-error --output /dev/null "${JENKINS_URL}"; then
    break
  fi
  sleep 2
done

if ! curl --fail --silent --show-error --output /dev/null "${JENKINS_URL}"; then
  echo "Jenkins did not become ready. Inspect: journalctl -u jenkins --no-pager -n 200" >&2
  exit 1
fi

echo
echo "Jenkins is active and enabled at boot."
echo "Service check: systemctl status jenkins --no-pager"
echo "Initial unlock password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
