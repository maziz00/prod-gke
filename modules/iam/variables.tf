variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name — used as a naming prefix for service accounts."
  type        = string
}

variable "node_sa_roles" {
  description = "IAM roles granted to the GKE node service account."
  type        = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ]
}

variable "vault_ksa_namespace" {
  description = "Kubernetes namespace of the Vault pod."
  type        = string
  default     = "vault"
}

variable "vault_ksa_name" {
  description = "Kubernetes ServiceAccount name used by Vault."
  type        = string
  default     = "vault"
}

variable "argocd_ksa_namespace" {
  description = "Kubernetes namespace where ArgoCD runs."
  type        = string
  default     = "argocd"
}

variable "argocd_ksa_name" {
  description = "Kubernetes ServiceAccount name used by ArgoCD application controller."
  type        = string
  default     = "argocd-application-controller"
}

variable "eso_ksa_namespace" {
  description = "Kubernetes namespace where External Secrets Operator runs."
  type        = string
  default     = "external-secrets"
}

variable "eso_ksa_name" {
  description = "Kubernetes ServiceAccount name used by External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "labels" {
  description = "Labels applied to all service accounts."
  type        = map(string)
  default     = {}
}
