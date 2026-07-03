#!/usr/bin/env bash
set -Eeuo pipefail

readonly CLUSTER_NAME="tripplanner-dev-eks"
readonly CONTROLLER_NAMESPACE="kube-system"
readonly REPOSITORY_ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/../.."
  pwd
)"

if [[ "$#" -ne 1 ]]; then
  echo "Usage: $0 <absolute-output-path-outside-the-repository>" >&2
  exit 1
fi

output_path="$1"
if [[ "${output_path}" != /* ]]; then
  echo "The backup output path must be absolute." >&2
  exit 1
fi

case "${output_path}" in
  "${REPOSITORY_ROOT}" | "${REPOSITORY_ROOT}"/*)
    echo "The controller key backup must be stored outside the Git repository." >&2
    exit 1
    ;;
esac

current_context="$(kubectl config current-context)"
if [[ "${current_context}" != *"${CLUSTER_NAME}"* ]]; then
  echo "kubectl context must target ${CLUSTER_NAME}; current context: ${current_context}" >&2
  exit 1
fi

umask 0077
temporary_file="$(mktemp)"
trap 'rm -f "${temporary_file}"' EXIT

kubectl get secret \
  --namespace "${CONTROLLER_NAMESPACE}" \
  --selector sealedsecrets.bitnami.com/sealed-secrets-key \
  --output=yaml \
  >"${temporary_file}"

if ! grep -q "tls.key:" "${temporary_file}"; then
  echo "No Sealed Secrets controller key was found." >&2
  exit 1
fi

install -m 0600 "${temporary_file}" "${output_path}"
echo "Controller key backup created at ${output_path}."
echo "Move it off the Jenkins Master and never commit it to Git."
