# Artifact Registry module.
#
# Provisions:
#   1. A Docker-format Artifact Registry repository for cluster images.
#   2. IAM: node SA gets reader (pull images); CI SA gets writer (push images).
#   3. CI service account with Workload Identity Federation for GitHub Actions.
#      GitHub Actions jobs authenticate via OIDC — no service account keys.
#
# WIF token flow:
#   GitHub Actions job → OIDC token (token.actions.githubusercontent.com)
#   → GCP WIF pool validates token against attribute_condition
#   → CI SA impersonation granted → Docker push to Artifact Registry

# ── Registry ────────────────────────────────────────────────────────────────

resource "google_artifact_registry_repository" "images" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  description   = "Docker images for ${var.cluster_name} workloads"
  format        = "DOCKER"

  labels = var.labels
}

# ── IAM: node SA can pull images ────────────────────────────────────────────
# Note: node SA already has roles/artifactregistry.reader at the project level
# (set in modules/iam node_sa_roles). This binding is repo-scoped as defense-in-depth.

resource "google_artifact_registry_repository_iam_member" "node_sa_reader" {
  project    = var.project_id
  location   = var.location
  repository = google_artifact_registry_repository.images.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.node_sa_email}"
}

# ── CI service account ───────────────────────────────────────────────────────

resource "google_service_account" "ci" {
  account_id   = "${var.cluster_name}-ci"
  display_name = "CI/CD SA — ${var.cluster_name}"
  description  = "Used by GitHub Actions via Workload Identity Federation. No SA keys."
  project      = var.project_id
}

resource "google_artifact_registry_repository_iam_member" "ci_writer" {
  project    = var.project_id
  location   = var.location
  repository = google_artifact_registry_repository.images.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.ci.email}"
}

# ── Workload Identity Federation for GitHub Actions ──────────────────────────

resource "google_iam_workload_identity_pool" "github_actions" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "WIF pool for GitHub Actions — no service account keys"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  # Security: restrict token exchange to your GitHub org only.
  # Other repositories in the same org cannot impersonate this SA.
  attribute_condition = "assertion.repository_owner == '${var.github_owner}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Allow GitHub Actions (from the specific repo) to impersonate the CI SA.
resource "google_service_account_iam_member" "ci_wi_binding" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  # Scoped to a specific GitHub repo — only this repo's Actions jobs can impersonate.
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/${var.github_owner}/${var.github_repo}"
}
