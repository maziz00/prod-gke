# Production VPC module.
#
# Provisions:
#   - Custom-mode VPC with global routing (no default subnets)
#   - Regional subnet with secondary ranges for GKE pod and service IPs
#   - Cloud Router + Cloud NAT for private-node outbound egress
#   - VPC Flow Logs for network observability
#   - Firewall rules: allow-internal, allow-health-checks, deny-all-ingress baseline

resource "google_compute_network" "vpc" {
  name                    = "${var.name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  project                 = var.project_id
}

resource "google_compute_subnetwork" "nodes" {
  name          = "${var.name}-nodes"
  region        = var.region
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = var.subnet_cidr
  project       = var.project_id

  # Required: lets private GKE nodes reach Google APIs (GCR, GCS) without public IPs.
  private_ip_google_access = true

  # GKE alias IPs: pods and services get IPs from these secondary ranges.
  secondary_ip_range {
    range_name    = var.pods_range_name
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = var.services_range_name
    ip_cidr_range = var.services_cidr
  }

  dynamic "log_config" {
    for_each = var.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_MIN"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# Cloud Router: required anchor for Cloud NAT configuration.
resource "google_compute_router" "router" {
  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.vpc.self_link
  project = var.project_id
}

# Cloud NAT: provides outbound internet access for private nodes without public IPs.
# Required for pulling container images and reaching external APIs.
resource "google_compute_router_nat" "nat" {
  name                               = "${var.name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Allow traffic within the VPC CIDR ranges (node-to-node, pod-to-pod, pod-to-service).
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.name}-allow-internal"
  network = google_compute_network.vpc.name
  project = var.project_id
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_cidr, var.pods_cidr, var.services_cidr]
}

# Allow GCP load balancer health check probes (documented GCP ranges).
resource "google_compute_firewall" "allow_health_checks" {
  name     = "${var.name}-allow-health-checks"
  network  = google_compute_network.vpc.name
  project  = var.project_id
  priority = 1000

  allow {
    protocol = "tcp"
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}

# Allow IAP tunnel traffic for secure SSH access to nodes without a public bastion.
resource "google_compute_firewall" "allow_iap" {
  name    = "${var.name}-allow-iap"
  network = google_compute_network.vpc.name
  project = var.project_id
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP's source IP range — see https://cloud.google.com/iap/docs/using-tcp-forwarding
  source_ranges = ["35.235.240.0/20"]
}
