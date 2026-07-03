#!/usr/bin/env bash
set -Eeuo pipefail

readonly VERSION="0.38.1"
readonly CLUSTER_NAME="tripplanner-dev-eks"
readonly CONTROLLER_NAMESPACE="kube-system"
readonly CONTROLLER_NAME="sealed-secrets-controller"
readonly RELEASE_URL="https://github.com/bitnami/sealed-secrets/releases/download/v${VERSION}"
readonly CONTROLLER_SHA256="d54b2a749fc07f741aaddec539dd6338f114120db61725e6e2cb251470a83da8"
readonly KUBESEAL_SHA256="71791ebf0c26675927153e7c2a4418ae769db27084931d24dee2ac58a3c76c2d"

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as the user that owns the kubectl context, not as root." >&2
  exit 1
fi

for command in curl kubectl sha256sum sudo tar; do
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

controller_manifest="${work_directory}/controller.yaml"
kubeseal_archive="${work_directory}/kubeseal.tar.gz"

curl \
  --fail \
  --location \
  --retry 5 \
  --retry-delay 3 \
  --silent \
  --show-error \
  --output "${controller_manifest}" \
  "${RELEASE_URL}/controller.yaml"
echo "${CONTROLLER_SHA256}  ${controller_manifest}" | sha256sum --check -

curl \
  --fail \
  --location \
  --retry 5 \
  --retry-delay 3 \
  --silent \
  --show-error \
  --output "${kubeseal_archive}" \
  "${RELEASE_URL}/kubeseal-${VERSION}-linux-amd64.tar.gz"
echo "${KUBESEAL_SHA256}  ${kubeseal_archive}" | sha256sum --check -

tar -xzf "${kubeseal_archive}" -C "${work_directory}" kubeseal
sudo install -m 0755 "${work_directory}/kubeseal" /usr/local/bin/kubeseal

kubectl apply -f "${controller_manifest}"
kubectl \
  --namespace "${CONTROLLER_NAMESPACE}" \
  rollout status "deployment/${CONTROLLER_NAME}" \
  --timeout=180s

kubeseal --version
echo "Sealed Secrets controller and kubeseal ${VERSION} are ready."
