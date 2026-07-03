#!/usr/bin/env bash
set -Eeuo pipefail

readonly VERSION="3.4.2"
readonly CLUSTER_NAME="tripplanner-dev-eks"
readonly NAMESPACE="argocd"
readonly INSTALL_URL="https://raw.githubusercontent.com/argoproj/argo-cd/v${VERSION}/manifests/install.yaml"
readonly CLI_URL="https://github.com/argoproj/argo-cd/releases/download/v${VERSION}/argocd-linux-amd64"
readonly CLI_SHA256="d4cb1ac8002baab8afaca2da3de597b613df8459074bc7c6d96dc95161c2a33f"

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as the user that owns the kubectl context, not as root." >&2
  exit 1
fi

for command in curl grep kubectl sha256sum sudo; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Required command is missing: ${command}" >&2
    exit 1
  fi
done

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "This pinned installer supports the Jenkins Master x86_64 architecture only." >&2
  exit 1
fi

current_context="$(kubectl config current-context)"
if [[ "${current_context}" != *"${CLUSTER_NAME}"* ]]; then
  echo "kubectl context must target ${CLUSTER_NAME}; current context: ${current_context}" >&2
  exit 1
fi

work_directory="$(mktemp -d)"
trap 'rm -rf "${work_directory}"' EXIT

install_manifest="${work_directory}/install.yaml"
argocd_binary="${work_directory}/argocd"

curl \
  --fail \
  --location \
  --retry 5 \
  --retry-delay 3 \
  --silent \
  --show-error \
  --output "${install_manifest}" \
  "${INSTALL_URL}"

if ! grep -q "quay.io/argoproj/argocd:v${VERSION}" "${install_manifest}"; then
  echo "The downloaded manifest does not contain the pinned ArgoCD image version." >&2
  exit 1
fi

if grep -qE 'image:.*:latest([[:space:]]|$)' "${install_manifest}"; then
  echo "The downloaded manifest unexpectedly contains a latest image tag." >&2
  exit 1
fi

curl \
  --fail \
  --location \
  --retry 5 \
  --retry-delay 3 \
  --silent \
  --show-error \
  --output "${argocd_binary}" \
  "${CLI_URL}"
echo "${CLI_SHA256}  ${argocd_binary}" | sha256sum --check -
sudo install -m 0755 "${argocd_binary}" /usr/local/bin/argocd

kubectl create namespace "${NAMESPACE}" \
  --dry-run=client \
  --output=yaml |
  kubectl apply -f -

kubectl apply \
  --namespace "${NAMESPACE}" \
  --server-side \
  --force-conflicts \
  --filename "${install_manifest}"

kubectl \
  --namespace "${NAMESPACE}" \
  wait \
  --for=condition=Available \
  deployment \
  --all \
  --timeout=300s

kubectl \
  --namespace "${NAMESPACE}" \
  rollout status statefulset/argocd-application-controller \
  --timeout=300s

argocd version --client
echo "ArgoCD ${VERSION} is ready in namespace ${NAMESPACE}."
