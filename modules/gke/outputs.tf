output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.primary.name
}

output "cluster_id" {
  description = "Full GKE cluster resource ID."
  value       = google_container_cluster.primary.id
}

output "cluster_endpoint" {
  description = "GKE API server endpoint."
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate."
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "GKE cluster region."
  value       = google_container_cluster.primary.location
}

output "workload_identity_pool" {
  description = "Workload Identity pool — use this as the annotation value for KSA→GSA bindings."
  value       = "${var.project_id}.svc.id.goog"
}

output "node_pool_names" {
  description = "Names of all managed node pools."
  value = [
    google_container_node_pool.system.name,
    google_container_node_pool.spot_apps.name,
  ]
}
