variable "project_id" {
  description = "GCP project ID where the cluster is deployed."
  type        = string
}

variable "region" {
  description = "GCP region. Regional clusters run the control plane across 3 zones for HA."
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Deployment environment (used as a resource label)."
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "environment must be production, staging, or development."
  }
}

variable "cluster_name" {
  description = "GKE cluster name."
  type        = string
  default     = "prod-gke"
}

variable "network_name" {
  description = "Naming prefix for VPC and related networking resources."
  type        = string
  default     = "prod-gke"
}

# --- Networking ---

variable "subnet_cidr" {
  description = "CIDR for the primary subnet (GKE nodes)."
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR for GKE pod IPs."
  type        = string
  default     = "10.48.0.0/14"
}

variable "services_cidr" {
  description = "Secondary CIDR for GKE service IPs."
  type        = string
  default     = "10.52.0.0/20"
}

variable "pods_range_name" {
  description = "Name of the secondary IP range for pods."
  type        = string
  default     = "k8s-pod-range"
}

variable "services_range_name" {
  description = "Name of the secondary IP range for services."
  type        = string
  default     = "k8s-service-range"
}

variable "master_ipv4_cidr_block" {
  description = "CIDR for the GKE master network (/28). Must not overlap with node/pod/service ranges."
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = <<-EOT
    List of CIDR blocks permitted to reach the GKE API server.
    Example: [{ cidr_block = "203.0.113.0/24", display_name = "Office VPN" }]
    Empty list = no restriction (API server accessible from internet — demo only).
  EOT
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs on the node subnet."
  type        = bool
  default     = true
}

# --- GKE Cluster ---

variable "release_channel" {
  description = "GKE release channel (RAPID | REGULAR | STABLE)."
  type        = string
  default     = "REGULAR"
}

variable "enable_binary_authorization" {
  description = "Enable Binary Authorization to enforce image attestation policies."
  type        = bool
  default     = true
}

variable "enable_managed_prometheus" {
  description = "Integrate with Google Managed Prometheus for Cloud Monitoring."
  type        = bool
  default     = false
}

variable "enable_nap" {
  description = "Enable Node Auto Provisioning (GKE-native dynamic node pool creation)."
  type        = bool
  default     = true
}

variable "nap_max_cpu" {
  description = "Maximum vCPUs Node Auto Provisioning can provision across all NAP pools."
  type        = number
  default     = 64
}

variable "nap_max_memory_gb" {
  description = "Maximum memory (GB) Node Auto Provisioning can provision."
  type        = number
  default     = 256
}

# --- Node Pools ---

variable "system_pool_machine_type" {
  description = "Machine type for the system node pool."
  type        = string
  default     = "e2-standard-4"
}

variable "system_pool_min" {
  description = "Minimum nodes per zone in the system pool."
  type        = number
  default     = 1
}

variable "system_pool_max" {
  description = "Maximum nodes per zone in the system pool."
  type        = number
  default     = 3
}

variable "spot_pool_machine_type" {
  description = "Machine type for the spot workload pool."
  type        = string
  default     = "e2-standard-4"
}

variable "spot_pool_min" {
  description = "Minimum nodes in the spot pool. 0 = scales to zero when idle."
  type        = number
  default     = 0
}

variable "spot_pool_max" {
  description = "Maximum nodes in the spot pool."
  type        = number
  default     = 10
}

variable "deletion_protection" {
  description = "Prevent accidental cluster deletion. Set to false during planned teardown."
  type        = bool
  default     = true
}

# --- Workload Identity KSA mappings ---
# These match the Kubernetes ServiceAccount names created by each Helm chart.
# Only change if you use non-default release names.

variable "vault_ksa_namespace" {
  description = "Namespace of the Vault Kubernetes ServiceAccount."
  type        = string
  default     = "vault"
}

variable "vault_ksa_name" {
  description = "Name of the Vault Kubernetes ServiceAccount."
  type        = string
  default     = "vault"
}

variable "argocd_ksa_namespace" {
  description = "Namespace of the ArgoCD application controller Kubernetes ServiceAccount."
  type        = string
  default     = "argocd"
}

variable "argocd_ksa_name" {
  description = "Name of the ArgoCD application controller Kubernetes ServiceAccount."
  type        = string
  default     = "argocd-application-controller"
}

variable "eso_ksa_namespace" {
  description = "Namespace of the External Secrets Operator Kubernetes ServiceAccount."
  type        = string
  default     = "external-secrets"
}

variable "eso_ksa_name" {
  description = "Name of the External Secrets Operator Kubernetes ServiceAccount."
  type        = string
  default     = "external-secrets"
}

variable "labels" {
  description = "Labels applied to all resources. Keys and values must be lowercase alphanumeric or hyphens."
  type        = map(string)
  default = {
    managed-by = "terraform"
    project    = "prod-gke"
  }
}

# --- Artifact Registry & CI/CD ---

variable "artifact_registry_repo_id" {
  description = "Artifact Registry repository ID (appears in the Docker image URL)."
  type        = string
  default     = "prod-gke"
}

variable "github_owner" {
  description = "GitHub organization or username that owns the prod-gke repository. Used to scope the Workload Identity Federation binding so only your repos can authenticate."
  type        = string
  default     = "maziz00"
}

variable "github_repo" {
  description = "GitHub repository name (without owner prefix). Scopes the WIF binding to a single repo."
  type        = string
  default     = "prod-gke"
}
