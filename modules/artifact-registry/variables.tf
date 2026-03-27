variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "location" {
  description = "Artifact Registry location (region)."
  type        = string
}

variable "repository_id" {
  description = "Artifact Registry repository ID (appears in the image URL)."
  type        = string
  default     = "prod-gke"
}

variable "cluster_name" {
  description = "GKE cluster name — used as a prefix for the CI service account."
  type        = string
}

variable "node_sa_email" {
  description = "GKE node SA email. Granted reader access to pull images."
  type        = string
}

variable "github_owner" {
  description = "GitHub organization or user name that owns the repository. Used as the WIF attribute_condition to restrict which repos can impersonate the CI SA."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without the owner prefix). Combined with github_owner to scope the WIF binding to a single repo."
  type        = string
  default     = "prod-gke"
}

variable "labels" {
  description = "Labels to apply to all resources."
  type        = map(string)
  default     = {}
}
