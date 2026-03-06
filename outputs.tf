output "cluster_name" {
  description = "Cluster Name"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "Cluster Endpoint"
  value       = google_container_cluster.primary.endpoint
}

output "cluster_location" {
  description = "Cluster Location"
  value       = google_container_cluster.primary.location
}

output "get_credentials_command" {
  description = "Command to get credentials"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location}"
}
