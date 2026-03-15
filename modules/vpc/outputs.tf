output "network_name" {
  description = "VPC network name."
  value       = google_compute_network.vpc.name
}

output "network_self_link" {
  description = "VPC network self-link (required by GKE cluster resource)."
  value       = google_compute_network.vpc.self_link
}

output "subnet_name" {
  description = "Primary subnet name."
  value       = google_compute_subnetwork.nodes.name
}

output "subnet_self_link" {
  description = "Primary subnet self-link (required by GKE cluster resource)."
  value       = google_compute_subnetwork.nodes.self_link
}

output "pods_range_name" {
  description = "Secondary range name for GKE pod IPs."
  value       = var.pods_range_name
}

output "services_range_name" {
  description = "Secondary range name for GKE service IPs."
  value       = var.services_range_name
}
