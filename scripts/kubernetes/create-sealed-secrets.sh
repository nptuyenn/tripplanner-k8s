#!/usr/bin/env bash
set -Eeuo pipefail

readonly CLUSTER_NAME="tripplanner-dev-eks"
readonly CONTROLLER_NAMESPACE="kube-system"
readonly CONTROLLER_NAME="sealed-secrets-controller"
readonly TARGET_NAMESPACE="tripplanner"
readonly REPOSITORY_ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/../.."
  pwd
)"
readonly AUTH_OUTPUT="${REPOSITORY_ROOT}/kubernetes/base/auth-service/sealed-secret.yaml"
readonly TRIP_OUTPUT="${REPOSITORY_ROOT}/kubernetes/base/trip-service/sealed-secret.yaml"

if [[ "$#" -lt 2 || "$#" -gt 3 ]]; then
  echo "Usage: $0 <auth-private-key.pem> <trip-public-key.pem> [--force]" >&2
  exit 1
fi

auth_private_key="$1"
trip_public_key="$2"
force="${3:-}"

if [[ -n "${force}" && "${force}" != "--force" ]]; then
  echo "The only supported third argument is --force." >&2
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

if [[ ! -r "${auth_private_key}" ]] ||
  ! grep -Eq 'BEGIN ([A-Z]+ )?PRIVATE KEY' "${auth_private_key}"; then
  echo "The Auth private-key file is missing, unreadable, or not PEM." >&2
  exit 1
fi

if [[ ! -r "${trip_public_key}" ]] ||
  ! grep -Eq 'BEGIN ([A-Z]+ )?PUBLIC KEY' "${trip_public_key}"; then
  echo "The Trip public-key file is missing, unreadable, or not PEM." >&2
  exit 1
fi

if [[ -z "${force}" && ( -e "${AUTH_OUTPUT}" || -e "${TRIP_OUTPUT}" ) ]]; then
  echo "A sealed-secret output already exists. Use --force only for intentional rotation." >&2
  exit 1
fi

read -r -s -p "Auth MongoDB Atlas URI: " auth_mongo_uri
echo
read -r -s -p "Trip MongoDB Atlas URI: " trip_mongo_uri
echo

if [[ -z "${auth_mongo_uri}" || -z "${trip_mongo_uri}" ]]; then
  echo "Both MongoDB Atlas URIs are required." >&2
  exit 1
fi

umask 0077
work_directory="$(mktemp -d)"

cleanup() {
  unset auth_mongo_uri trip_mongo_uri
  rm -rf "${work_directory}"
}
trap cleanup EXIT

printf '%s' "${auth_mongo_uri}" >"${work_directory}/auth-mongo-uri"
printf '%s' "${trip_mongo_uri}" >"${work_directory}/trip-mongo-uri"

kubectl create secret generic auth-service-secrets \
  --namespace "${TARGET_NAMESPACE}" \
  --from-file="AUTH_MONGO_URI=${work_directory}/auth-mongo-uri" \
  --from-file="JWT_PRIVATE_KEY=${auth_private_key}" \
  --dry-run=client \
  --output=json |
  kubeseal \
    --controller-name "${CONTROLLER_NAME}" \
    --controller-namespace "${CONTROLLER_NAMESPACE}" \
    --scope strict \
    --format yaml \
    >"${work_directory}/auth-sealed-secret.yaml"

kubectl create secret generic trip-service-secrets \
  --namespace "${TARGET_NAMESPACE}" \
  --from-file="TRIP_MONGO_URI=${work_directory}/trip-mongo-uri" \
  --from-file="JWT_PUBLIC_KEY=${trip_public_key}" \
  --dry-run=client \
  --output=json |
  kubeseal \
    --controller-name "${CONTROLLER_NAME}" \
    --controller-namespace "${CONTROLLER_NAMESPACE}" \
    --scope strict \
    --format yaml \
    >"${work_directory}/trip-sealed-secret.yaml"

grep -q "encryptedData:" "${work_directory}/auth-sealed-secret.yaml"
grep -q "encryptedData:" "${work_directory}/trip-sealed-secret.yaml"

install -m 0644 "${work_directory}/auth-sealed-secret.yaml" "${AUTH_OUTPUT}"
install -m 0644 "${work_directory}/trip-sealed-secret.yaml" "${TRIP_OUTPUT}"

for kustomization in \
  "${REPOSITORY_ROOT}/kubernetes/base/auth-service/kustomization.yaml" \
  "${REPOSITORY_ROOT}/kubernetes/base/trip-service/kustomization.yaml"; do
  if ! grep -qx '  - sealed-secret.yaml' "${kustomization}"; then
    sed -i '/  - configmap.yaml/a\  - sealed-secret.yaml' "${kustomization}"
  fi
done

kubectl kustomize "${REPOSITORY_ROOT}/kubernetes/base" >/dev/null

echo "Created encrypted manifests:"
echo "  ${AUTH_OUTPUT}"
echo "  ${TRIP_OUTPUT}"
echo "No plaintext secret was written into the repository."
