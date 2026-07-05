#!/usr/bin/env bash
set -Eeuo pipefail

readonly CHART_VERSION="1.14.0"
readonly CONTROLLER_VERSION="v2.14.1"
readonly CLUSTER_NAME="tripplanner-dev-eks"
readonly AWS_REGION="us-east-1"
readonly NAMESPACE="kube-system"
readonly RELEASE_NAME="aws-load-balancer-controller"
readonly SERVICE_ACCOUNT_NAME="aws-load-balancer-controller"
readonly CHART_REPOSITORY_NAME="eks"
readonly CHART_REPOSITORY_URL="https://aws.github.io/eks-charts"
readonly CHART_REFERENCE="${CHART_REPOSITORY_NAME}/aws-load-balancer-controller"

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as the user that owns the kubectl context, not as root." >&2
  exit 1
fi

if (( $# > 1 )); then
  echo "Usage: $0 [load-balancer-controller-role-arn]" >&2
  exit 1
fi

role_arn="${1:-${AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN:-}}"
if [[ ! "${role_arn}" =~ ^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$ ]]; then
  echo "Provide the IRSA role ARN as the first argument or AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN." >&2
  exit 1
fi

for command in aws grep helm kubectl; do
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

cluster_status="$(
  aws eks describe-cluster \
    --name "${CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --query 'cluster.status' \
    --output text
)"
if [[ "${cluster_status}" != "ACTIVE" ]]; then
  echo "EKS cluster ${CLUSTER_NAME} must be ACTIVE; current status: ${cluster_status}" >&2
  exit 1
fi

vpc_id="$(
  aws eks describe-cluster \
    --name "${CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --query 'cluster.resourcesVpcConfig.vpcId' \
    --output text
)"
if [[ ! "${vpc_id}" =~ ^vpc-[0-9a-f]+$ ]]; then
  echo "Could not determine the VPC ID for ${CLUSTER_NAME}." >&2
  exit 1
fi

helm repo add \
  "${CHART_REPOSITORY_NAME}" \
  "${CHART_REPOSITORY_URL}" \
  --force-update
helm repo update "${CHART_REPOSITORY_NAME}"

chart_metadata="$(
  helm show chart \
    "${CHART_REFERENCE}" \
    --version "${CHART_VERSION}"
)"
if ! grep -qE "^version: ['\"]?${CHART_VERSION}['\"]?$" <<<"${chart_metadata}"; then
  echo "The downloaded chart metadata does not match chart version ${CHART_VERSION}." >&2
  exit 1
fi
if ! grep -qE "^appVersion: ['\"]?${CONTROLLER_VERSION}['\"]?$" <<<"${chart_metadata}"; then
  echo "The chart does not contain controller version ${CONTROLLER_VERSION}." >&2
  exit 1
fi

work_directory="$(mktemp -d)"
trap 'rm -rf "${work_directory}"' EXIT

helm pull \
  "${CHART_REFERENCE}" \
  --version "${CHART_VERSION}" \
  --untar \
  --untardir "${work_directory}"

kubectl apply \
  --server-side \
  --filename "${work_directory}/aws-load-balancer-controller/crds"

kubectl create serviceaccount "${SERVICE_ACCOUNT_NAME}" \
  --namespace "${NAMESPACE}" \
  --dry-run=client \
  --output=yaml |
  kubectl apply --filename -

kubectl annotate serviceaccount "${SERVICE_ACCOUNT_NAME}" \
  --namespace "${NAMESPACE}" \
  "eks.amazonaws.com/role-arn=${role_arn}" \
  --overwrite

helm upgrade \
  --install "${RELEASE_NAME}" \
  "${CHART_REFERENCE}" \
  --namespace "${NAMESPACE}" \
  --version "${CHART_VERSION}" \
  --set "clusterName=${CLUSTER_NAME}" \
  --set "region=${AWS_REGION}" \
  --set "vpcId=${vpc_id}" \
  --set "serviceAccount.create=false" \
  --set "serviceAccount.name=${SERVICE_ACCOUNT_NAME}" \
  --set "replicaCount=2" \
  --atomic \
  --wait \
  --timeout 10m

kubectl rollout status \
  deployment/aws-load-balancer-controller \
  --namespace "${NAMESPACE}" \
  --timeout=300s

installed_role_arn="$(
  kubectl get serviceaccount "${SERVICE_ACCOUNT_NAME}" \
    --namespace "${NAMESPACE}" \
    --output=jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
)"
if [[ "${installed_role_arn}" != "${role_arn}" ]]; then
  echo "The ServiceAccount IRSA role annotation does not match the requested role." >&2
  exit 1
fi

helm status "${RELEASE_NAME}" --namespace "${NAMESPACE}"
kubectl get deployment,pods \
  --namespace "${NAMESPACE}" \
  --selector=app.kubernetes.io/name=aws-load-balancer-controller

echo "AWS Load Balancer Controller ${CONTROLLER_VERSION} is ready."
echo "Chart version: ${CHART_VERSION}"
echo "Cluster: ${CLUSTER_NAME}"
echo "VPC: ${vpc_id}"
