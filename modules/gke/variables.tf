variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region. Cluster is deployed as regional for control-plane HA across 3 zones."
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name."
  type        = string
}

variable "environment" {
  description = "Deployment environment label (e.g. production, staging)."
  type        = string
  default     = "production"
}

variable "network" {
  description = "VPC network name (output of vpc module)."
  type        = string
}

variable "subnetwork" {
  description = "Subnet name for nodes (output of vpc module)."
  type        = string
}

variable "pods_range_name" {
  description = "Secondary IP range name for pod IPs (output of vpc module)."
  type        = string
}

variable "services_range_name" {
  description = "Secondary IP range name for service IPs (output of vpc module)."
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "CIDR for the GKE master network. Must be /28 and not overlap with node/pod/service CIDRs."
  type        = string
  default     = "172.16.0.0/28"

  validation {
    condition     = can(cidrhost(var.master_ipv4_cidr_block, 0))
    error_message = "master_ipv4_cidr_block must be a valid CIDR (e.g. 172.16.0.0/28)."
  }
}

variable "master_authorized_networks" {
  description = <<-EOT
    List of CIDRs allowed to reach the GKE API server.
    For production, restrict to known office/VPN IP ranges.
    Empty list disables the master authorized networks feature (not recommended).
  EOT
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "release_channel" {
  description = "GKE release channel. REGULAR provides tested K8s versions with auto-upgrade."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR, or STABLE."
  }
}

variable "node_sa_email" {
  description = "Service account email for GKE node VMs (output of iam module)."
  type        = string
}

variable "enable_binary_authorization" {
  description = "Enable Binary Authorization to block unverified container images."
  type        = bool
  default     = true
}

variable "enable_managed_prometheus" {
  description = "Enable Google Managed Prometheus integration for Cloud Monitoring."
  type        = bool
  default     = false
}

variable "enable_nap" {
  description = "Enable Node Auto Provisioning — GKE creates node pools on demand for unschedulable pods."
  type        = bool
  default     = true
}

variable "nap_max_cpu" {
  description = "Maximum total vCPUs that Node Auto Provisioning can provision."
  type        = number
  default     = 64
}

variable "nap_max_memory_gb" {
  description = "Maximum total memory (GB) that Node Auto Provisioning can provision."
  type        = number
  default     = 256
}

variable "system_pool_machine_type" {
  description = "Machine type for the system node pool (runs platform components: ArgoCD, Istio, Prometheus, Vault)."
  type        = string
  default     = "e2-standard-4"
}

variable "system_pool_min" {
  description = "Minimum nodes per zone in the system pool."
  type        = number
  default     = 1
}

variable "system_pool_max" {
  description = "Maximum nodes per zone in the system pool."
  type        = number
  default     = 3
}

variable "spot_pool_machine_type" {
  description = "Machine type for the spot workload pool (up to 91% cheaper than on-demand)."
  type        = string
  default     = "e2-standard-4"
}

variable "spot_pool_min" {
  description = "Minimum nodes in the spot pool (0 = scale to zero when no workloads scheduled)."
  type        = number
  default     = 0
}

variable "spot_pool_max" {
  description = "Maximum nodes in the spot pool."
  type        = number
  default     = 10
}

variable "deletion_protection" {
  description = "Prevent accidental cluster deletion via terraform destroy. Set to false only during teardown."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to the cluster and all node pools."
  type        = map(string)
  default     = {}
}
