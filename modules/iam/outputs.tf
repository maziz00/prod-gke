output "node_sa_email" {
  description = "Email of the GKE node pool service account."
  value       = google_service_account.gke_nodes.email
}

output "node_sa_id" {
  description = "Full resource ID of the GKE node service account."
  value       = google_service_account.gke_nodes.name
}

output "vault_sa_email" {
  description = "Email of the Vault GCP service account (for WI annotation and KMS config)."
  value       = google_service_account.vault.email
}

output "vault_sa_id" {
  description = "Full resource ID of the Vault service account (used for WI IAM binding)."
  value       = google_service_account.vault.name
}

output "argocd_sa_email" {
  description = "Email of the ArgoCD GCP service account."
  value       = google_service_account.argocd.email
}

output "argocd_sa_id" {
  description = "Full resource ID of the ArgoCD service account (used for WI IAM binding)."
  value       = google_service_account.argocd.name
}

output "eso_sa_email" {
  description = "Email of the External Secrets Operator GCP service account."
  value       = google_service_account.eso.email
}

output "eso_sa_id" {
  description = "Full resource ID of the ESO service account (used for WI IAM binding)."
  value       = google_service_account.eso.name
}
