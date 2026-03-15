# prod-gke-platform — Root Module
#
# Composes three independent modules into a complete production GKE platform:
#   - vpc:  Private networking, Cloud NAT, VPC Flow Logs, firewall rules
#   - iam:  GCP service accounts + Workload Identity bindings (no service account keys)
#   - gke:  Private GKE cluster + node pools + NAP + security hardening
#
# Deployment order:
#   1. IAM module (creates service accounts — GKE module references node SA email)
#   2. VPC module (creates network — GKE module references network/subnet links)
#   3. GKE module (consumes outputs from iam and vpc modules)
#
# After `terraform apply`, bootstrap ArgoCD and the GitOps App-of-Apps:
#   bash scripts/bootstrap-argocd.sh

module "iam" {
  source = "./modules/iam"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  node_sa_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ]
  labels = var.labels
}

module "vpc" {
  source = "./modules/vpc"

  project_id          = var.project_id
  name                = var.network_name
  region              = var.region
  subnet_cidr         = var.subnet_cidr
  pods_cidr           = var.pods_cidr
  services_cidr       = var.services_cidr
  pods_range_name     = var.pods_range_name
  services_range_name = var.services_range_name
  enable_flow_logs    = var.enable_flow_logs
  labels              = var.labels
}

module "gke" {
  source = "./modules/gke"

  project_id   = var.project_id
  region       = var.region
  cluster_name = var.cluster_name
  environment  = var.environment

  # Networking (from vpc module outputs)
  network             = module.vpc.network_name
  subnetwork          = module.vpc.subnet_name
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name

  master_ipv4_cidr_block     = var.master_ipv4_cidr_block
  master_authorized_networks = var.master_authorized_networks

  # IAM (from iam module outputs)
  node_sa_email = module.iam.node_sa_email

  # Cluster configuration
  release_channel             = var.release_channel
  enable_binary_authorization = var.enable_binary_authorization
  enable_managed_prometheus   = var.enable_managed_prometheus
  enable_nap                  = var.enable_nap
  nap_max_cpu                 = var.nap_max_cpu
  nap_max_memory_gb           = var.nap_max_memory_gb

  # Node pools
  system_pool_machine_type = var.system_pool_machine_type
  system_pool_min          = var.system_pool_min
  system_pool_max          = var.system_pool_max
  spot_pool_machine_type   = var.spot_pool_machine_type
  spot_pool_min            = var.spot_pool_min
  spot_pool_max            = var.spot_pool_max

  deletion_protection = var.deletion_protection
  labels              = var.labels
}
