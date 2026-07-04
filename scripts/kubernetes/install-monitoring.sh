#!/usr/bin/env bash
set -Eeuo pipefail

readonly CHART_VERSION="87.7.0"
readonly CHART_REFERENCE="oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack"
readonly CLUSTER_NAME="tripplanner-dev-eks"
readonly NAMESPACE="monitoring"
readonly RELEASE_NAME="monitoring"
readonly GRAFANA_SECRET_NAME="monitoring-grafana-admin"
readonly STORAGE_CLASS_NAME="tripplanner-gp3"
readonly REPOSITORY_ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/../.."
  pwd
)"
readonly VALUES_FILE="${REPOSITORY_ROOT}/kubernetes/monitoring/values.yaml"
readonly STORAGE_CLASS_FILE="${REPOSITORY_ROOT}/kubernetes/monitoring/storage-class.yaml"

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as the user that owns the kubectl context, not as root." >&2
  exit 1
fi

for command in awk grep helm kubectl; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Required command is missing: ${command}" >&2
    exit 1
  fi
done

for required_file in "${VALUES_FILE}" "${STORAGE_CLASS_FILE}"; do
  if [[ ! -f "${required_file}" ]]; then
    echo "Required monitoring file is missing: ${required_file}" >&2
    exit 1
  fi
done

current_context="$(kubectl config current-context)"
if [[ "${current_context}" != *"${CLUSTER_NAME}"* ]]; then
  echo "kubectl context must target ${CLUSTER_NAME}; current context: ${current_context}" >&2
  exit 1
fi

ready_nodes="$(
  kubectl get nodes \
    --no-headers |
    awk '$2 == "Ready" { count++ } END { print count + 0 }'
)"
if (( ready_nodes < 2 )); then
  echo "At least two schedulable Ready nodes are required; found ${ready_nodes}." >&2
  exit 1
fi

if ! kubectl get csidriver ebs.csi.aws.com >/dev/null 2>&1; then
  echo "The EBS CSI driver is required for monitoring persistent volumes." >&2
  exit 1
fi

kubectl apply --filename "${STORAGE_CLASS_FILE}"

storage_provisioner="$(
  kubectl get storageclass "${STORAGE_CLASS_NAME}" \
    --output=jsonpath='{.provisioner}'
)"
if [[ "${storage_provisioner}" != "ebs.csi.aws.com" ]]; then
  echo "StorageClass ${STORAGE_CLASS_NAME} must use the EBS CSI provisioner." >&2
  exit 1
fi

chart_metadata="$(
  helm show chart \
    "${CHART_REFERENCE}" \
    --version "${CHART_VERSION}"
)"
if ! grep -q "^version: ${CHART_VERSION}$" <<<"${chart_metadata}"; then
  echo "The downloaded chart metadata does not match version ${CHART_VERSION}." >&2
  exit 1
fi

kubectl create namespace "${NAMESPACE}" \
  --dry-run=client \
  --output=yaml |
  kubectl apply -f -

if ! kubectl get secret \
  --namespace "${NAMESPACE}" \
  "${GRAFANA_SECRET_NAME}" \
  >/dev/null 2>&1; then
  grafana_admin_password="${GRAFANA_ADMIN_PASSWORD:-}"
  if [[ -z "${grafana_admin_password}" ]]; then
    if [[ ! -t 0 ]]; then
      echo "Set GRAFANA_ADMIN_PASSWORD when running without an interactive terminal." >&2
      exit 1
    fi

    read -r -s -p "Grafana admin password (minimum 16 characters): " grafana_admin_password
    echo
  fi

  if (( ${#grafana_admin_password} < 16 )); then
    echo "Grafana admin password must contain at least 16 characters." >&2
    exit 1
  fi

  password_file="$(mktemp)"
  trap 'rm -f "${password_file}"' EXIT
  chmod 0600 "${password_file}"
  printf '%s' "${grafana_admin_password}" >"${password_file}"

  kubectl create secret generic "${GRAFANA_SECRET_NAME}" \
    --namespace "${NAMESPACE}" \
    --from-literal=admin-user=admin \
    --from-file="admin-password=${password_file}"

  unset grafana_admin_password
fi

helm template "${RELEASE_NAME}" \
  "${CHART_REFERENCE}" \
  --namespace "${NAMESPACE}" \
  --version "${CHART_VERSION}" \
  --values "${VALUES_FILE}" \
  >/dev/null

helm upgrade \
  --install "${RELEASE_NAME}" \
  "${CHART_REFERENCE}" \
  --namespace "${NAMESPACE}" \
  --version "${CHART_VERSION}" \
  --values "${VALUES_FILE}" \
  --atomic \
  --wait \
  --timeout 15m

kubectl \
  --namespace "${NAMESPACE}" \
  rollout status deployment/monitoring-grafana \
  --timeout=300s

kubectl \
  --namespace "${NAMESPACE}" \
  rollout status deployment/monitoring-kube-prometheus-operator \
  --timeout=300s

kubectl \
  --namespace "${NAMESPACE}" \
  rollout status statefulset/prometheus-monitoring-kube-prometheus-prometheus \
  --timeout=300s

kubectl \
  --namespace "${NAMESPACE}" \
  rollout status statefulset/alertmanager-monitoring-kube-prometheus-alertmanager \
  --timeout=300s

helm status "${RELEASE_NAME}" --namespace "${NAMESPACE}"
kubectl get pods --namespace "${NAMESPACE}"

echo "Monitoring stack ${CHART_VERSION} is ready in namespace ${NAMESPACE}."
echo "Grafana and Prometheus remain private ClusterIP services."
