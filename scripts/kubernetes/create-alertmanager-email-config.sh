#!/usr/bin/env bash
set -Eeuo pipefail

readonly CLUSTER_NAME="tripplanner-dev-eks"
readonly CONTROLLER_NAMESPACE="kube-system"
readonly CONTROLLER_NAME="sealed-secrets-controller"
readonly TARGET_NAMESPACE="tripplanner"
readonly SECRET_NAME="alertmanager-email"
readonly REPOSITORY_ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/../.."
  pwd
)"
readonly OBSERVABILITY_DIRECTORY="${REPOSITORY_ROOT}/kubernetes/base/observability"
readonly CONFIG_OUTPUT="${OBSERVABILITY_DIRECTORY}/alertmanager-config.yaml"
readonly SECRET_OUTPUT="${OBSERVABILITY_DIRECTORY}/alertmanager-email-sealed-secret.yaml"
readonly KUSTOMIZATION="${OBSERVABILITY_DIRECTORY}/kustomization.yaml"

if [[ "$#" -gt 1 ]]; then
  echo "Usage: $0 [--force]" >&2
  exit 1
fi

force="${1:-}"
if [[ -n "${force}" && "${force}" != "--force" ]]; then
  echo "The only supported argument is --force." >&2
  exit 1
fi

for command in grep install kubectl kubeseal mktemp sed; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Required command is missing: ${command}" >&2
    exit 1
  fi
done

current_context="$(kubectl config current-context)"
if [[ "${current_context}" != *"${CLUSTER_NAME}"* ]]; then
  echo "kubectl context must target ${CLUSTER_NAME}; current context: ${current_context}" >&2
  exit 1
fi

if [[ -z "${force}" && ( -e "${CONFIG_OUTPUT}" || -e "${SECRET_OUTPUT}" ) ]]; then
  echo "Alertmanager email output already exists. Use --force only for intentional rotation." >&2
  exit 1
fi

read -r -p "Gmail sender address: " sender_address
read -r -p "Alert recipient address [${sender_address}]: " recipient_address
recipient_address="${recipient_address:-${sender_address}}"
read -r -s -p "Gmail App Password: " smtp_password
echo
smtp_password="${smtp_password// /}"

email_pattern='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
if [[ ! "${sender_address}" =~ ${email_pattern} ]] ||
  [[ ! "${recipient_address}" =~ ${email_pattern} ]]; then
  echo "Sender and recipient must be valid email addresses." >&2
  exit 1
fi

if (( ${#smtp_password} < 16 )); then
  echo "Gmail App Password must contain at least 16 characters." >&2
  exit 1
fi

umask 0077
work_directory="$(mktemp -d)"

cleanup() {
  unset smtp_password
  rm -rf "${work_directory}"
}
trap cleanup EXIT

printf '%s' "${smtp_password}" >"${work_directory}/smtp-password"

kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${TARGET_NAMESPACE}" \
  --from-file="smtp-password=${work_directory}/smtp-password" \
  --dry-run=client \
  --output=json |
  kubeseal \
    --controller-name "${CONTROLLER_NAME}" \
    --controller-namespace "${CONTROLLER_NAMESPACE}" \
    --scope strict \
    --format yaml \
    >"${work_directory}/sealed-secret.yaml"

grep -q "encryptedData:" "${work_directory}/sealed-secret.yaml"

{
  echo "apiVersion: monitoring.coreos.com/v1alpha1"
  echo "kind: AlertmanagerConfig"
  echo "metadata:"
  echo "  name: tripplanner-email"
  echo "  labels:"
  echo "    alertmanagerConfig: tripplanner"
  echo "    app.kubernetes.io/name: tripplanner-email"
  echo "    app.kubernetes.io/component: monitoring"
  echo "    app.kubernetes.io/part-of: tripplanner"
  echo "spec:"
  echo "  route:"
  echo "    receiver: tripplanner-email"
  echo "    groupBy:"
  echo "      - alertname"
  echo "      - service"
  echo "      - severity"
  echo "    groupWait: 15s"
  echo "    groupInterval: 1m"
  echo "    repeatInterval: 4h"
  echo "  receivers:"
  echo "    - name: tripplanner-email"
  echo "      emailConfigs:"
  echo "        - to: \"${recipient_address}\""
  echo "          from: \"${sender_address}\""
  echo "          smarthost: smtp.gmail.com:465"
  echo "          authUsername: \"${sender_address}\""
  echo "          authPassword:"
  echo "            name: ${SECRET_NAME}"
  echo "            key: smtp-password"
  echo "          requireTLS: true"
  echo "          forceImplicitTLS: true"
  echo "          sendResolved: true"
} >"${work_directory}/alertmanager-config.yaml"

install -m 0644 "${work_directory}/sealed-secret.yaml" "${SECRET_OUTPUT}"
install -m 0644 "${work_directory}/alertmanager-config.yaml" "${CONFIG_OUTPUT}"

for resource in alertmanager-config.yaml alertmanager-email-sealed-secret.yaml; do
  if ! grep -qx "  - ${resource}" "${KUSTOMIZATION}"; then
    sed -i "/resources:/a\\  - ${resource}" "${KUSTOMIZATION}"
  fi
done

kubectl kustomize "${REPOSITORY_ROOT}/kubernetes/base" >/dev/null

echo "Created Alertmanager email manifests:"
echo "  ${CONFIG_OUTPUT}"
echo "  ${SECRET_OUTPUT}"
echo "No plaintext Gmail App Password was written into the repository."
