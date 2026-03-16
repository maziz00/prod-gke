#!/bin/bash
# setup-tf-backend.sh
#
# One-shot bootstrap for prod-gke:
#   1. Enable required GCP APIs
#   2. Create GCS bucket for Terraform remote state (idempotent)
#   3. Write backend.tf with the real bucket name
#   4. Run terraform init so the backend is active immediately
#
# Usage:
#   bash scripts/setup-tf-backend.sh
#
# Requires: gcloud (authenticated), terraform >= 1.9

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TFVARS="${ROOT_DIR}/terraform.tfvars"
BACKEND_TF="${ROOT_DIR}/backend.tf"

# ── Helpers ─────────────────────────────────────────────────────────────────

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

# ── Read project config from terraform.tfvars ───────────────────────────────

[[ -f "$TFVARS" ]] || die "terraform.tfvars not found at $TFVARS — copy terraform.tfvars.example first"

# Extract values; fall back to safe defaults if line is absent.
PROJECT_ID=$(grep -E '^project_id\s*=' "$TFVARS" | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d '[:space:]')
REGION=$(grep -E '^region\s*='     "$TFVARS" | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d '[:space:]')
REGION="${REGION:-us-central1}"

[[ -n "$PROJECT_ID" ]] || die "project_id not found in terraform.tfvars"

BUCKET="${PROJECT_ID}-prod-gke-tfstate"

log "Project : $PROJECT_ID"
log "Region  : $REGION"
log "Bucket  : gs://$BUCKET"
echo ""

# ── Step 1: Enable required GCP APIs ────────────────────────────────────────

log "Enabling required GCP APIs..."

APIS=(
  container.googleapis.com            # GKE
  compute.googleapis.com              # VPC, firewall, Cloud NAT
  iam.googleapis.com                  # Service accounts, IAM bindings
  iamcredentials.googleapis.com       # Workload Identity token exchange
  artifactregistry.googleapis.com     # Container image pull from Artifact Registry
  secretmanager.googleapis.com        # Vault auto-unseal + ESO backend
  cloudkms.googleapis.com             # Vault GCP KMS seal
  cloudresourcemanager.googleapis.com # Terraform resource management API
  storage.googleapis.com              # GCS (remote state bucket)
  dns.googleapis.com                  # Cloud DNS for cluster DNS
  monitoring.googleapis.com           # Cloud Monitoring
  logging.googleapis.com              # Cloud Logging
  binaryauthorization.googleapis.com  # Binary Authorization for image attestation
)

gcloud services enable "${APIS[@]}" --project="$PROJECT_ID"
log "APIs enabled."
echo ""

# ── Step 2: Create GCS bucket for Terraform state ───────────────────────────

log "Checking for state bucket gs://$BUCKET..."

if gcloud storage buckets describe "gs://$BUCKET" --project="$PROJECT_ID" &>/dev/null; then
  log "Bucket already exists — skipping creation."
else
  log "Creating bucket..."
  gcloud storage buckets create "gs://$BUCKET" \
    --project="$PROJECT_ID" \
    --location="$REGION" \
    --uniform-bucket-level-access \
    --public-access-prevention

  log "Enabling object versioning (allows state rollback)..."
  gcloud storage buckets update "gs://$BUCKET" --versioning

  log "Bucket created."
fi
echo ""

# ── Step 3: Write backend.tf ─────────────────────────────────────────────────

log "Writing backend.tf..."

cat > "$BACKEND_TF" << EOF
# Remote state — GCS
# Bucket created by: scripts/setup-tf-backend.sh
# Do not edit manually.

terraform {
  backend "gcs" {
    bucket = "${BUCKET}"
    prefix = "prod-gke/state"
  }
}
EOF

log "backend.tf updated: bucket=${BUCKET}, prefix=prod-gke/state"
echo ""

# ── Step 4: terraform init ───────────────────────────────────────────────────

log "Running terraform init to activate the GCS backend..."
cd "$ROOT_DIR"
terraform init -reconfigure

echo ""
log "================================================================"
log "Backend ready. Next steps:"
log "  terraform plan"
log "  terraform apply"
log "  bash scripts/bootstrap-argocd.sh   # after apply completes"
log "================================================================"
