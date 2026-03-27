output "repository_url" {
  description = "Full Artifact Registry URL. Use as the Docker image base: <url>/IMAGE_NAME:TAG"
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${var.repository_id}"
}

output "ci_sa_email" {
  description = "CI service account email. Set as GCP_CI_SA_EMAIL in GitHub Actions secrets."
  value       = google_service_account.ci.email
}

output "wif_provider" {
  description = "Full WIF provider resource name. Set as GCP_WIF_PROVIDER in GitHub Actions secrets."
  value       = google_iam_workload_identity_pool_provider.github.name
}
