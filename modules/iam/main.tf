# IAM module.
#
# Provisions GCP service accounts and Workload Identity bindings for:
#   - GKE node pools (least-privilege IAM roles only)
#   - Vault (Secret Manager access + WI binding to vault KSA)
#   - ArgoCD (no extra GCP permissions needed; WI binding for future GCS artifact access)
#   - External Secrets Operator (Secret Manager accessor + WI binding)
#
# Workload Identity: Kubernetes pods authenticate to GCP APIs using a KSA annotation
# that maps to a GCP service account. No service account keys are ever created or stored.

# --- GKE Node Service Account ---

resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE Node SA — ${var.cluster_name}"
  description  = "Attached to all GKE node VMs. Minimum permissions per CIS GKE Benchmark."
  project      = var.project_id
}

resource "google_project_iam_member" "node_roles" {
  for_each = toset(var.node_sa_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# --- Vault Service Account ---
# Vault needs Secret Manager access for the GCP KMS auto-unseal and to serve as a secret backend.

resource "google_service_account" "vault" {
  account_id   = "${var.cluster_name}-vault"
  display_name = "Vault SA — ${var.cluster_name}"
  description  = "Used by Vault via Workload Identity. Grants Secret Manager and KMS access."
  project      = var.project_id
}

resource "google_project_iam_member" "vault_secret_manager" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.vault.email}"
}

resource "google_project_iam_member" "vault_kms_decrypter" {
  project = var.project_id
  role    = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member  = "serviceAccount:${google_service_account.vault.email}"
}

# NOTE: Workload Identity bindings (vault_wi, argocd_wi, eso_wi) are intentionally
# defined in the ROOT main.tf — not here. The WI pool (PROJECT.svc.id.goog) is only
# created after the GKE cluster exists, so those resources need depends_on = [module.gke].
# Defining them here would cause a race condition with parallel module execution.

# --- ArgoCD Service Account ---

resource "google_service_account" "argocd" {
  account_id   = "${var.cluster_name}-argocd"
  display_name = "ArgoCD SA — ${var.cluster_name}"
  description  = "Used by ArgoCD via Workload Identity."
  project      = var.project_id
}


# --- External Secrets Operator Service Account ---
# ESO syncs secrets from Vault/Secret Manager into Kubernetes native Secrets.

resource "google_service_account" "eso" {
  account_id   = "${var.cluster_name}-eso"
  display_name = "External Secrets Operator SA — ${var.cluster_name}"
  description  = "Used by ESO to read from Secret Manager via Workload Identity."
  project      = var.project_id
}

resource "google_project_iam_member" "eso_secret_manager" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eso.email}"
}

