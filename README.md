# Production-Grade GKE Cluster with Terraform

## 🚀 Overview
This repository contains Terraform code to provision a **Production-Grade Google Kubernetes Engine (GKE)** cluster. It is designed to showcase advanced DevOps practices, including **Infrastructure as Code (IaC)**, **Security (DevSecOps)**, **Cost Optimization**, and **Scalability**.

This project is intended for Engineering Leaders and Hiring Managers to demonstrate expertise in building resilient, secure, and automated cloud infrastructure.

## 🏗 Architecture Highlights
- **Private GKE Cluster**: Control plane and nodes are isolated from the public internet.
- **VPC-Native Networking**: Utilizing Alias IPs for high performance and direct pod-to-pod communication.
- **Security First**:
  - **Workload Identity**: Securely map Kubernetes Service Accounts to Google Cloud IAM Service Accounts (no long-lived keys).
  - **Shielded GKE Nodes**: Verifiable integrity of the node OS.
  - **Private Nodes**: Nodes have no public IPs; outbound access via Cloud NAT.
- **Cost Optimization**:
  - **Spot Instances (Preemptible)**: Used for stateless workloads to reduce costs by up to 80%.
  - **Cluster Autoscaler**: Automatically scales node pools based on demand.
- **Observability**: Integrated with Google Cloud Operations (formerly Stackdriver) for logging and monitoring.

## 📂 Directory Structure
```
.
├── main.tf             # Root module orchestration
├── variables.tf        # Input variables definition
├── outputs.tf          # Key outputs (Cluster Endpoint, etc.)
├── versions.tf         # Provider & Terraform version constraints
├── terraform.tfvars    # Configuration values (Git-ignored in real scenarios)
└── modules/            # Reusable modules (optional, using direct resources for simplicity in this demo)
```

## 🛠 Prerequisites
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0.0
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (gcloud) installed and authenticated.
- A GCP Project with billing enabled.
- Required APIs enabled: `compute.googleapis.com`, `container.googleapis.com`.

## 🚀 Deployment Guide

### 1. Initialize Terraform
```bash
terraform init
```

### 2. Review the Plan
```bash
terraform plan
```

### 3. Apply Infrastructure
```bash
terraform apply
```

### 4. Connect to Cluster
```bash
gcloud container clusters get-credentials <CLUSTER_NAME> --region <REGION>
```

### 5. Bootstrap GitOps (ArgoCD)
This project includes a helper script to install ArgoCD (HA mode) for GitOps workflows.
```bash
./scripts/bootstrap-gitops.sh <CLUSTER_NAME> <REGION>
```

## 🧠 Advanced Usage

### Workload Identity
This cluster uses Workload Identity to securely access GCP resources from Kubernetes pods.

1. **Create a Kubernetes Service Account (KSA)**:
   ```bash
   kubectl create serviceaccount my-app-sa --namespace default
   ```
2. **Bind KSA to a Google Service Account (GSA)**:
   ```bash
   gcloud iam service-accounts add-iam-policy-binding <GSA_EMAIL> \
       --role roles/iam.workloadIdentityUser \
       --member "serviceAccount:<PROJECT_ID>.svc.id.goog[default/my-app-sa]"
   ```
3. **Annotate the KSA**:
   ```bash
   kubectl annotate serviceaccount my-app-sa \
       --namespace default \
       iam.gke.io/gcp-service-account=<GSA_EMAIL>
   ```

### Network Policies
Dataplane V2 is enabled, allowing you to use Kubernetes NetworkPolicies to control traffic between pods.

Example `NetworkPolicy` to deny all ingress traffic by default:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

## 🔐 Security & Best Practices Implemented
| Category | Implementation |
|----------|----------------|
| **Network** | Custom VPC, Private Subnet, Cloud NAT, Authorized Networks |
| **IAM** | Least Privilege Service Accounts, Workload Identity |
| **Compute** | Container-Optimized OS (COS), Shielded Nodes |
| **Operations** | Auto-repair, Auto-upgrade, Cloud Logging/Monitoring |

---
*Built by [Your Name] - DevOps & Cloud Architect*
