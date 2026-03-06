provider "google" {
  project = var.project_id
  region  = var.region
}

# ---------------------------------------------------------------------------------------------------------------------
# VPC NETWORK & SUBNET
# ---------------------------------------------------------------------------------------------------------------------

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.0.0.0/16"

  secondary_ip_range {
    range_name    = var.pods_range_name
    ip_cidr_range = "10.48.0.0/14"
  }

  secondary_ip_range {
    range_name    = var.services_range_name
    ip_cidr_range = "10.52.0.0/20"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUD NAT (REQUIRED FOR PRIVATE NODES)
# ---------------------------------------------------------------------------------------------------------------------

resource "google_compute_router" "router" {
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.vpc.name
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# GKE CLUSTER SERVICE ACCOUNT (LEAST PRIVILEGE)
# ---------------------------------------------------------------------------------------------------------------------

resource "google_service_account" "gke_sa" {
  account_id   = "${var.cluster_name}-sa"
  display_name = "GKE Node Service Account"
}

resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

resource "google_project_iam_member" "metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

resource "google_project_iam_member" "monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

resource "google_project_iam_member" "stackdriver_writer" {
  project = var.project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}
# Necessary for pulling images from GCR
resource "google_project_iam_member" "artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

# ---------------------------------------------------------------------------------------------------------------------
# GKE CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  networking_mode = "VPC_NATIVE"
  
  # VPC-native networking config
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private Cluster Config
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Set to true to restrict access to master completely
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Security & Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  
  # Dataplane V2 (Cilium based network policies)
  datapath_provider = "ADVANCED_DATAPATH"

  # Maintenance & Release
  release_channel {
    channel = "REGULAR"
  }
  
  # Enable Shielded Nodes
  enable_shielded_nodes = true

  # Master Authorized Networks (Optional but recommended)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "Allow All (Demo)"
    }
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }
  
  # Ensure the cluster is destroyed only after node pools are deleted
  lifecycle {
    ignore_changes = [node_pool]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# NODE POOLS
# ---------------------------------------------------------------------------------------------------------------------

# 1. System Node Pool (High availability, On-Demand)
resource "google_container_node_pool" "system_pool" {
  name       = "system-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1 # Per zone

  node_config {
    machine_type = "e2-standard-2"
    
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      team = "devops"
      role = "system"
    }

    # Shielded Instance Config
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
  
  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# 2. Workload Node Pool (Cost optimized, Spot/Preemptible, Autoscaling)
resource "google_container_node_pool" "workload_pool" {
  name       = "workload-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  
  autoscaling {
    min_node_count = 0
    max_node_count = 5
  }

  node_config {
    machine_type = "e2-standard-4"
    spot         = true # Use Spot instances for cost savings

    service_account = google_service_account.gke_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      team = "engineering"
      role = "workload"
    }

    # Taint the nodes so only workloads that tolerate it run here
    taint {
      key    = "instance_type"
      value  = "spot"
      effect = "NO_SCHEDULE"
    }
    
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
  
  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
