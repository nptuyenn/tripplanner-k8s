# TripPlanner Kubernetes & Infrastructure

This repository is the GitOps and infrastructure source of truth for
TripPlanner. Application source code and the Jenkins pipeline live in the
separate `tripplanner-app` repository.

The repository is currently scaffolded only. Kubernetes manifests and Terraform
resources will be added in their corresponding phases.

## Repository structure

```text
tripplanner-k8s/
├── kubernetes/
│   ├── argocd/                 # Argo CD Application definitions
│   ├── base/
│   │   ├── frontend/           # Frontend Deployment and Service
│   │   ├── auth-service/       # Auth Deployment, Service and ConfigMap
│   │   ├── trip-service/       # Trip Deployment, Service and ConfigMap
│   │   ├── redis/              # Redis Deployment and Service
│   │   ├── networking/         # NetworkPolicy resources
│   │   ├── observability/      # ServiceMonitor, alerts and dashboards
│   │   └── secrets/            # Encrypted/external secret declarations
│   └── overlays/
│       └── dev/                # Development environment customizations
└── terraform/
    ├── bootstrap/              # Remote state bootstrap
    ├── environments/
    │   └── dev/                # Development root module
    └── modules/                # Reusable infrastructure modules
```

## Repository boundaries

- `tripplanner-app` builds and scans the frontend, Auth Service, and Trip
  Service images.
- CI publishes immutable image tags and later updates only the matching image
  reference in this repository.
- Argo CD watches `kubernetes/overlays/dev` and reconciles the EKS cluster.
- Terraform provisions AWS infrastructure but is not modified by the
  application delivery pipeline.
- Plaintext secrets, Terraform state, private keys, and local environment files
  must never be committed.

