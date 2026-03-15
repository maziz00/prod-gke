variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "name" {
  description = "Resource naming prefix (used for VPC, subnet, router, NAT)."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR range for the primary subnet (GKE nodes)."
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR range for GKE pod IP aliases."
  type        = string
  default     = "10.48.0.0/14"
}

variable "services_cidr" {
  description = "Secondary CIDR range for GKE service IPs."
  type        = string
  default     = "10.52.0.0/20"
}

variable "pods_range_name" {
  description = "Name of the secondary IP range for pods."
  type        = string
  default     = "k8s-pod-range"
}

variable "services_range_name" {
  description = "Name of the secondary IP range for services."
  type        = string
  default     = "k8s-service-range"
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs on the primary subnet (recommended for security auditing)."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to all resources."
  type        = map(string)
  default     = {}
}
