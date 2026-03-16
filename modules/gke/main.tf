# Production GKE cluster module.
#
# Security features enabled:
#   - Private nodes (no public node IPs) + private endpoint optional
#   - Workload Identity (pods use KSA→GSA binding for GCP auth, no service account keys)
#   - Dataplane V2 (Cilium eBPF) for L4/L7 NetworkPolicy enforcement
#   - Shielded Nodes (Secure Boot + vTPM integrity monitoring)
#   - Binary Authorization (blocks containers without attestation)
#   - GKE Security Posture (workload config audit + vulnerability scanning)
#   - Maintenance windows aligned to off-peak Gulf Standard Time
#
# Scalability features:
#   - Node Auto Provisioning (GKE-native Karpenter equivalent)
#   - Vertical Pod Autoscaling
#   - Gateway API (next-gen ingress replacing Ingress API)
#   - Cloud DNS for lower-latency cluster DNS vs kube-dns
#
# Node pools:
#   - system: on-demand e2-standard-4, taint CriticalAddonsOnly, for platform tooling
#   - spot-apps: spot e2-standard-4, autoscaling 0→N, for tenant workloads

locals {
  common_labels = merge(var.labels, {
    cluster        = var.cluster_name
    environment    = var.environment
    managed-by     = "terraform"
  })
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Discard the auto-created node pool; all pools are managed below.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network
  subnetwork = var.subnetwork

  # VPC-native networking: pods get IPs routed directly through the VPC
  # (no IP masquerade required), enabling inter-pod visibility across subnets.
  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private cluster: nodes have no external IPs.
  # enable_private_endpoint=false keeps the API server reachable from master_authorized_networks.
  # Set enable_private_endpoint=true for fully air-gapped clusters (requires VPN or bastion).
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Restrict API server access to known CIDR ranges.
  # Leave empty to allow 0.0.0.0/0 (demo only — always lock this down in production).
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  # Workload Identity: maps Kubernetes ServiceAccounts to GCP service accounts.
  # Pods use this instead of service account key files — no secrets to rotate or leak.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Dataplane V2 uses eBPF (Cilium) for NetworkPolicy enforcement.
  # Supports L4 + L7 policies, better observability than kube-proxy + iptables.
  datapath_provider = "ADVANCED_DATAPATH"

  release_channel {
    channel = var.release_channel
  }

  # Shielded Nodes: Secure Boot prevents loading unsigned kernel modules;
  # integrity monitoring verifies boot measurements via vTPM.
  enable_shielded_nodes = true

  # Binary Authorization: in ENFORCE mode, only containers with valid attestations
  # from a trusted attestor (e.g. Cloud Build SLSA) are admitted.
  binary_authorization {
    evaluation_mode = var.enable_binary_authorization ? "PROJECT_SINGLETON_POLICY_ENFORCE" : "DISABLED"
  }

  # Vertical Pod Autoscaling: Kubernetes right-sizes container resource requests
  # based on actual usage. Runs alongside HPA.
  vertical_pod_autoscaling {
    enabled = true
  }

  # Gateway API: successor to Ingress (more expressive routing, supports Istio gateway binding).
  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  # Cloud DNS: cluster DNS backed by GCP DNS infrastructure.
  # Significantly lower latency than kube-dns for high-traffic clusters.
  dns_config {
    cluster_dns        = "CLOUD_DNS"
    cluster_dns_scope  = "CLUSTER_SCOPE"
    cluster_dns_domain = "cluster.local"
  }

  # Node Auto Provisioning: GKE's equivalent of Karpenter.
  # Automatically creates new node pools when workloads cannot be scheduled on existing pools.
  # Scales to zero and selects optimal machine families based on pod resource requests.
  cluster_autoscaling {
    enabled             = var.enable_nap
    autoscaling_profile = "OPTIMIZE_UTILIZATION"

    resource_limits {
      resource_type = "cpu"
      minimum       = 4
      maximum       = var.nap_max_cpu
    }

    resource_limits {
      resource_type = "memory"
      minimum       = 16
      maximum       = var.nap_max_memory_gb
    }

    auto_provisioning_defaults {
      service_account = var.node_sa_email
      oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
      disk_size       = 100
      disk_type       = "pd-balanced"
      image_type      = "COS_CONTAINERD"

      management {
        auto_repair  = true
        auto_upgrade = true
      }

      shielded_instance_config {
        enable_secure_boot          = true
        enable_integrity_monitoring = true
      }

      upgrade_settings {
        strategy        = "SURGE"
        max_surge       = 1
        max_unavailable = 0
      }
    }
  }

  addons_config {
    http_load_balancing {
      disabled = false # Required for GCP L7 LB NEG backend integration.
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true # Required for PVCs using pd-ssd / pd-balanced.
    }
    dns_cache_config {
      enabled = true # NodeLocal DNSCache reduces pod DNS lookup latency.
    }
    # Disable the legacy network policy addon — ADVANCED_DATAPATH (Cilium) handles this.
    network_policy_config {
      disabled = true
    }
  }

  # GKE Security Posture: continuous workload configuration audit + vulnerability scanning.
  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  # Cloud Logging.
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  # Cloud Monitoring. Set enable_managed_prometheus=true to ship metrics to GMP.
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "DAEMONSET", "DEPLOYMENT", "STATEFULSET"]

    dynamic "managed_prometheus" {
      for_each = var.enable_managed_prometheus ? [1] : []
      content {
        enabled = true
      }
    }
  }

  # Maintenance window: Friday + Saturday nights UTC (maps to early morning GST both days).
  # GKE requires >=48h total maintenance availability in any 32-day window.
  # 2 nights × 8h = 16h/week = ~64h/month — well above the minimum.
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-05T22:00:00Z"
      end_time   = "2024-01-06T06:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=FR,SA"
    }
  }

  # Block accidental `terraform destroy` in production.
  deletion_protection = var.deletion_protection

  resource_labels = local.common_labels

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}

# --- System Node Pool ---
# On-demand VMs reserved for platform components (ArgoCD, Istio control plane,
# Prometheus stack, Vault). These must not be preempted mid-operation.

resource "google_container_node_pool" "system" {
  name     = "${var.cluster_name}-system"
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  autoscaling {
    min_node_count = var.system_pool_min
    max_node_count = var.system_pool_max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1
    max_unavailable = 0 # Zero-downtime rolling upgrades.
  }

  node_config {
    machine_type = var.system_pool_machine_type
    disk_size_gb = 50
    disk_type    = "pd-ssd"
    image_type   = "COS_CONTAINERD"

    service_account = var.node_sa_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Required for Workload Identity to work at pod level.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Block v0.1/v1beta1 metadata endpoints (legacy; credentials exposed via these).
    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Taint: only pods with a matching toleration land on system nodes.
    # Platform Helm charts set this toleration; tenant workloads don't.
    taint {
      key    = "CriticalAddonsOnly"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    labels = merge(local.common_labels, {
      node-pool     = "system"
      workload-type = "platform"
    })
  }
}

# --- Spot Workload Pool ---
# Spot VMs (up to 91% cheaper than on-demand) for tenant application workloads.
# Workloads on this pool must tolerate preemption (design for restart-resilience).

resource "google_container_node_pool" "spot_apps" {
  name     = "${var.cluster_name}-spot-apps"
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  autoscaling {
    min_node_count = var.spot_pool_min
    max_node_count = var.spot_pool_max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 2
    max_unavailable = 1 # Allow one unavailable during upgrades for faster turnaround.
  }

  node_config {
    machine_type = var.spot_pool_machine_type
    disk_size_gb = 100
    disk_type    = "pd-balanced"
    image_type   = "COS_CONTAINERD"
    spot         = true # Spot VMs: up to 91% cheaper; preemptable by GCP with 30s notice.

    service_account = var.node_sa_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Standard GKE spot taint — workloads opt in by tolerating this.
    taint {
      key    = "cloud.google.com/gke-spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    labels = merge(local.common_labels, {
      node-pool                    = "spot-apps"
      workload-type                = "tenant"
      "cloud.google.com/gke-spot" = "true"
    })
  }
}
