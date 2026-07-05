# TripPlanner Infrastructure and GitOps

This repository provisions and operates the AWS infrastructure, Kubernetes
workloads, GitOps delivery, and monitoring stack for TripPlanner. Application
source code and the Jenkins pipeline live in the separate `tripplanner-app`
repository.

The deployed request path is:

```text
Internet
  |
  v
CloudFront distribution (public HTTPS)
  |
  v
CloudFront VPC Origin
  |
  v
Internal Application Load Balancer
  |
  v
Frontend Service -> nginx
                    |-- /api/auth  -> Auth Service -> MongoDB Atlas + Redis
                    `-- /api/trips -> Trip Service -> MongoDB Atlas + Redis
```

The EKS API, internal ALB, application services, Jenkins, SonarQube, Grafana,
Prometheus, Alertmanager, and Argo CD remain private. CloudFront is the public
entry point.

## What This Repository Manages

- VPC, public and private subnets, NAT gateway, routing, and security groups
- Jenkins Master and Worker EC2 instances accessed through AWS Systems Manager
- Private-endpoint Amazon EKS cluster and managed node group
- EKS networking, DNS, kube-proxy, and EBS CSI managed add-ons
- IAM roles for EKS, EBS CSI, VPC CNI, and AWS Load Balancer Controller
- Kubernetes application manifests and network policies
- Sealed Secrets for encrypted configuration in Git
- Argo CD automated synchronization, pruning, and self-healing
- Prometheus, Alertmanager, Grafana, metrics collection, and alert rules
- Internal ALB ingress and public CloudFront HTTPS delivery

## Repository Layout

```text
tripplanner-k8s/
├── kubernetes/
│   ├── argocd/
│   │   ├── application.yaml
│   │   └── kustomization.yaml
│   ├── base/
│   │   ├── auth-service/
│   │   ├── frontend/
│   │   ├── observability/
│   │   ├── redis/
│   │   ├── trip-service/
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   └── network-policies.yaml
│   └── monitoring/
│       ├── storage-class.yaml
│       └── values.yaml
├── scripts/
│   ├── jenkins/
│   └── kubernetes/
├── terraform/
│   ├── bootstrap/
│   ├── environments/
│   │   └── dev/
│   └── modules/
│       ├── edge/
│       ├── eks/
│       ├── iam/
│       ├── jenkins/
│       ├── network/
│       └── security-groups/
├── .gitignore
└── README.md
```

Argo CD watches `kubernetes/base` on the `main` branch.

## Deployed Components

| Component | Deployment model |
|---|---|
| Frontend | 2 replicas, ClusterIP Service, internal ALB Ingress |
| Auth Service | 2 replicas, ClusterIP Service |
| Trip Service | 2 replicas, ClusterIP Service |
| Redis | 1 ephemeral replica, ClusterIP Service |
| EKS nodes | 2 `t3.large` nodes, autoscaling maximum 3 |
| Jenkins | Master and inbound WebSocket Worker on separate EC2 instances |
| Monitoring | `kube-prometheus-stack` with persistent Prometheus and Alertmanager data |
| Public edge | CloudFront with HTTPS redirect and security headers |

All application containers run as non-root with restricted security contexts.
Network policies default-deny inbound traffic and only allow required service
paths and Prometheus scraping.

## Prerequisites

### Windows administration machine

- AWS CLI v2 authenticated to the target AWS account
- Terraform `>= 1.10, < 2.0`
- Git
- AWS Session Manager plugin

### Jenkins Master

The Jenkins Master is the Kubernetes administration host because the EKS API
endpoint is private. It requires:

- AWS CLI
- `kubectl`
- Helm
- Git
- `curl`, `openssl`, and standard Linux utilities

Do not run the Kubernetes commands in this README on the Jenkins Worker.

## Terraform Configuration

Terraform state is stored in an encrypted, versioned S3 bucket. The bucket is a
long-lived bootstrap resource and should not be destroyed with the application
environment.

Before using another AWS account or region:

1. Update `terraform/bootstrap/terraform.tfvars`.
2. Create the remote-state bucket.
3. Update the bucket and region in `terraform/environments/dev/backend.tf`.
4. Create or update `terraform/environments/dev/terraform.tfvars`.

Example development variables:

```hcl
aws_region              = "us-east-1"
expected_aws_account_id = "123456789012"
project_name            = "tripplanner"
environment             = "dev"
owner                   = "your-name"
admin_cidrs             = []
ssh_public_key          = null
```

An empty `admin_cidrs` keeps administrative ports and the EKS public API
closed. AWS Systems Manager is the expected access method.

Never commit Terraform state, plan files, credentials, private keys, or
environment-specific secrets.

## Provision the Remote-State Bucket

Run on **Windows PowerShell**:

```powershell
Set-Location D:\tripplan\tripplanner-k8s\terraform\bootstrap
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform show -no-color tfplan
terraform apply tfplan
```

Confirm that the plan only creates the intended state bucket resources before
applying it.

## Provision or Update the AWS Environment

Run on **Windows PowerShell**:

```powershell
Set-Location D:\tripplan\tripplanner-k8s\terraform\environments\dev
aws sts get-caller-identity
terraform init -reconfigure
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform show -no-color tfplan
terraform apply tfplan
```

Always inspect replacements and destroys before applying. The public edge
depends on the internal ALB created by the Kubernetes Ingress. For a brand-new
environment, provision the core infrastructure and cluster services first,
allow Argo CD to create the internal ALB, and then plan/apply the CloudFront
edge resources.

Useful outputs:

```powershell
terraform output -raw jenkins_master_instance_id
terraform output -raw eks_cluster_name
terraform output -raw eks_load_balancer_controller_role_arn
terraform output -raw tripplanner_public_url
```

## Connect to the Jenkins Master

Obtain the instance ID from Terraform and start an SSM shell on **Windows
PowerShell**:

```powershell
Set-Location D:\tripplan\tripplanner-k8s\terraform\environments\dev
$MasterId = terraform output -raw jenkins_master_instance_id

aws ssm start-session `
  --target $MasterId `
  --region us-east-1
```

On the **Jenkins Master**, configure `kubectl`:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name tripplanner-dev-eks

kubectl config current-context
kubectl get nodes -o wide
```

The scripts reject an empty or incorrect Kubernetes context to reduce the risk
of changing the wrong cluster.

## Install Cluster Services

Run the following commands on the **Jenkins Master** from the cloned
`tripplanner-k8s` repository.

### 1. Sealed Secrets

```bash
bash scripts/kubernetes/install-sealed-secrets.sh
```

Generate application keys outside the repository:

```bash
mkdir -p "$HOME/.tripplanner-secrets"
chmod 700 "$HOME/.tripplanner-secrets"

openssl genpkey \
  -algorithm RSA \
  -pkeyopt rsa_keygen_bits:2048 \
  -out "$HOME/.tripplanner-secrets/jwt-private.pem"

openssl rsa \
  -in "$HOME/.tripplanner-secrets/jwt-private.pem" \
  -pubout \
  -out "$HOME/.tripplanner-secrets/jwt-public.pem"

chmod 600 "$HOME/.tripplanner-secrets/"*.pem
```

Create encrypted manifests. The script securely prompts for the Auth and Trip
MongoDB Atlas URIs:

```bash
bash scripts/kubernetes/create-sealed-secrets.sh \
  "$HOME/.tripplanner-secrets/jwt-private.pem" \
  "$HOME/.tripplanner-secrets/jwt-public.pem"
```

Use `--force` only for an intentional secret rotation. Back up the Sealed
Secrets controller key to an encrypted path outside the repository:

```bash
bash scripts/kubernetes/backup-sealed-secrets-key.sh \
  "$HOME/.tripplanner-secrets/sealed-secrets-controller-key.yaml"
```

Without that controller key, existing `SealedSecret` manifests cannot be
decrypted after a cluster rebuild and must be resealed.

### 2. AWS Load Balancer Controller

Obtain `eks_load_balancer_controller_role_arn` from Terraform on Windows, then
pass it to the installer on the **Jenkins Master**:

```bash
bash scripts/kubernetes/install-aws-load-balancer-controller.sh \
  "arn:aws:iam::123456789012:role/ROLE_NAME"
```

The script installs the pinned chart and uses the existing Terraform-managed
IAM role.

### 3. Monitoring

```bash
bash scripts/kubernetes/install-monitoring.sh
```

The installer creates the GP3 StorageClass and installs the pinned
`kube-prometheus-stack` release. It prompts for a Grafana administrator
password if the expected Kubernetes Secret does not already exist.

Optional email alert routing:

```bash
bash scripts/kubernetes/create-alertmanager-email-config.sh
```

The script prompts for the sender, recipient, and SMTP app password and writes
only encrypted secret material to the repository. Re-run the monitoring
installer after changing monitoring Helm values.

### 4. Argo CD and the TripPlanner Application

```bash
bash scripts/kubernetes/install-argocd.sh
kubectl apply -k kubernetes/argocd
```

Argo CD automatically synchronizes `kubernetes/base`, prunes removed
resources, and repairs configuration drift.

## Validate the Deployment

Run on the **Jenkins Master**:

```bash
kubectl -n argocd get application tripplanner
kubectl -n tripplanner get pods
kubectl -n tripplanner get services
kubectl -n tripplanner get ingress frontend
kubectl -n tripplanner get targetgroupbindings
kubectl -n kube-system get deployment aws-load-balancer-controller
kubectl -n monitoring get pods
kubectl -n monitoring get pvc
kubectl -n tripplanner get \
  servicemonitors,prometheusrules,alertmanagerconfigs
```

Expected application state:

- Argo CD: `Synced` and `Healthy`
- Application pods: `Running` and ready
- Frontend Service: `ClusterIP`
- Frontend Ingress: an internal ALB address
- AWS Load Balancer Controller: two available replicas
- Monitoring pods: ready
- Prometheus and Alertmanager PVCs: `Bound`

Get the public application URL on **Windows PowerShell**:

```powershell
Set-Location D:\tripplan\tripplanner-k8s\terraform\environments\dev
$PublicUrl = terraform output -raw tripplanner_public_url
curl.exe -fsS "$PublicUrl/healthz"
curl.exe -I "$PublicUrl/"
```

## GitOps Delivery Flow

```text
Application commit
  -> Jenkins path-based validation and security gates
  -> Docker Hub image tagged with the Git short SHA
  -> Jenkins updates only the affected image tag in kustomization.yaml
  -> Git commit in tripplanner-k8s
  -> Argo CD reconciliation
  -> Kubernetes rolling update
```

Application CI does not run Terraform and does not directly apply Kubernetes
manifests. This keeps infrastructure changes separate from application
delivery.

To inspect deployed image tags on the **Jenkins Master**:

```bash
kubectl -n tripplanner get deployments \
  -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image
```

## Access Private Interfaces

### Jenkins

Run on **Windows PowerShell**:

```powershell
$MasterId = terraform `
  -chdir=D:\tripplan\tripplanner-k8s\terraform\environments\dev `
  output -raw jenkins_master_instance_id

aws ssm start-session `
  --target $MasterId `
  --document-name AWS-StartPortForwardingSession `
  --parameters "portNumber=8080,localPortNumber=18080" `
  --region us-east-1
```

Open <http://localhost:18080>.

### Grafana

First run on the **Jenkins Master** and leave it open:

```bash
kubectl -n monitoring port-forward \
  service/monitoring-grafana 3000:80
```

In another terminal on **Windows PowerShell**, forward the Jenkins Master port:

```powershell
aws ssm start-session `
  --target $MasterId `
  --document-name AWS-StartPortForwardingSession `
  --parameters "portNumber=3000,localPortNumber=3000" `
  --region us-east-1
```

Open <http://localhost:3000>. Retrieve the generated password only when needed
on the **Jenkins Master**:

```bash
kubectl -n monitoring get secret monitoring-grafana-admin \
  -o jsonpath='{.data.admin-password}' |
  base64 -d
echo
```

### Argo CD

First run on the **Jenkins Master** and leave it open:

```bash
kubectl -n argocd port-forward \
  service/argocd-server 18081:443
```

Then run on **Windows PowerShell**:

```powershell
aws ssm start-session `
  --target $MasterId `
  --document-name AWS-StartPortForwardingSession `
  --parameters "portNumber=18081,localPortNumber=18081" `
  --region us-east-1
```

Open <https://localhost:18081>. A browser warning is expected for the local
port-forwarded certificate.

## Monitoring and Alerts

Prometheus discovers both backend services through `ServiceMonitor` resources.
The repository defines alerts for:

- Auth Service unavailable
- Trip Service unavailable
- High HTTP error rate
- High request latency
- Repeated pod restarts
- High pod CPU usage
- High pod memory usage

The provisioned Grafana dashboard shows RED metrics for both APIs: request
rate, errors, and duration. Alertmanager uses the encrypted email configuration
when it is present.

Quick Prometheus target check on the **Jenkins Master**:

```bash
kubectl -n monitoring port-forward \
  pod/prometheus-monitoring-kube-prometheus-prometheus-0 \
  19090:9090
```

In another Jenkins Master shell:

```bash
curl -fsS \
  'http://127.0.0.1:19090/api/v1/query?query=sum%28up%7Bnamespace%3D%22tripplanner%22%2Cjob%3D~%22auth-service%7Ctrip-service%22%7D%29'
```

With two replicas of each backend, the expected result is `4`.

## Secrets and Recovery

- Commit only encrypted `SealedSecret` manifests.
- Keep JWT private keys, SMTP app passwords, MongoDB credentials, Terraform
  credentials, and Jenkins credentials outside Git.
- Back up the Sealed Secrets controller key in encrypted storage.
- Preserve Jenkins credentials and configuration using an approved backup
  process.
- A Git clone alone is not sufficient to recover encrypted secrets without the
  Sealed Secrets controller key.
- Rotate a secret by resealing it, committing the encrypted manifest, and
  allowing Argo CD to reconcile it.

## Operational Checks

Run on the **Jenkins Master**:

```bash
kubectl -n argocd get application tripplanner
kubectl -n tripplanner get pods
kubectl -n tripplanner rollout status deployment/frontend --timeout=180s
kubectl -n tripplanner rollout status deployment/auth-service --timeout=180s
kubectl -n tripplanner rollout status deployment/trip-service --timeout=180s
kubectl -n tripplanner get events --sort-by=.lastTimestamp
```

Run on **Windows PowerShell**:

```powershell
terraform `
  -chdir=D:\tripplan\tripplanner-k8s\terraform\environments\dev `
  plan -detailed-exitcode
```

Terraform exit code `0` means no drift, `2` means changes are present, and `1`
means an error occurred.

## Rollback

Application rollback is Git-driven:

1. Change an affected image tag in `kubernetes/base/kustomization.yaml` to a
   previously validated immutable SHA.
2. Commit and push the change.
3. Confirm Argo CD returns to `Synced` and `Healthy`.
4. Verify the corresponding Kubernetes rollout and run the public E2E test.

Do not use `latest` image tags.

## Cleanup

AWS resources in this repository incur ongoing cost. Cleanup order matters
because CloudFront, the VPC origin, ALB, target groups, security groups, EBS
volumes, and EKS resources depend on one another.

For an intentional teardown:

1. Remove the CloudFront distribution and VPC origin.
2. Remove the Argo CD application or frontend Ingress and wait for the AWS Load
   Balancer Controller to delete the ALB and target resources.
3. Remove monitoring releases and persistent volumes if their data is no
   longer required.
4. Destroy the remaining development environment with Terraform.
5. Keep the remote-state bucket unless state retention is no longer required
   and a separate, reviewed process approves its removal.

Always create and inspect a Terraform destroy plan before applying it. Never
delete the state bucket first.
