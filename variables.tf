variable "project_id" {
  description = "The Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "The region to deploy to"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "prod-gke-cluster"
}

variable "network_name" {
  description = "The VPC network name"
  type        = string
  default     = "gke-network"
}

variable "subnet_name" {
  description = "The VPC subnet name"
  type        = string
  default     = "gke-subnet"
}

variable "pods_range_name" {
  description = "The name of the secondary range for pods"
  type        = string
  default     = "k8s-pod-range"
}

variable "services_range_name" {
  description = "The name of the secondary range for services"
  type        = string
  default     = "k8s-service-range"
}

variable "master_ipv4_cidr_block" {
  description = "The CIDR block for the master network"
  type        = string
  default     = "172.16.0.0/28"
}
