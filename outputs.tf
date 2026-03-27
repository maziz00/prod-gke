output "cluster_name" {
  description = "GKE cluster name."
  value       = module.gke.cluster_name
}

output "gcp_project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "cluster_location" {
  description = "GKE cluster region."
  value       = module.gke.cluster_location
}

output "cluster_endpoint" {
  description = "GKE API server endpoint (sensitive)."
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "workload_identity_pool" {
  description = "Workload Identity pool for KSA→GSA annotations."
  value       = module.gke.workload_identity_pool
}

output "node_sa_email" {
  description = "GKE node pool service account email."
  value       = module.iam.node_sa_email
}

output "vault_sa_email" {
  description = "Vault GCP service account email (use in Vault Helm values for WI annotation)."
  value       = module.iam.vault_sa_email
}

output "eso_sa_email" {
  description = "External Secrets Operator GCP service account email."
  value       = module.iam.eso_sa_email
}

output "node_pool_names" {
  description = "Names of all node pools."
  value       = module.gke.node_pool_names
}

output "get_credentials_command" {
  description = "Run this command to configure kubectl."
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${module.gke.cluster_location} --project ${var.project_id}"
}

output "artifact_registry_url" {
  description = "Artifact Registry URL. Use as the Docker image base: <url>/IMAGE_NAME:TAG"
  value       = module.artifact_registry.repository_url
}

output "ci_sa_email" {
  description = "CI service account email. Set as GCP_CI_SA_EMAIL in GitHub Actions secrets."
  value       = module.artifact_registry.ci_sa_email
}

output "wif_provider" {
  description = "WIF provider resource name. Set as GCP_WIF_PROVIDER in GitHub Actions secrets."
  value       = module.artifact_registry.wif_provider
}
