#!/bin/bash
# cleanup-orphans.sh
#
# Deletes GCP resources that exist outside Terraform state.
# Use when `terraform state list` returns empty but GCP resources still exist
# (caused by a failed apply that wrote partial state).
#
# After this script completes, run:
#   terraform apply
#
# CAUTION: This permanently deletes cloud resources. Verify the project ID before running.

set -euo pipefail

PROJECT="${1:-$(grep -E '^project_id' "$(dirname "$0")/../terraform.tfvars" | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d '[:space:]')}"
REGION="${2:-us-central1}"
CLUSTER="${3:-prod-gke}"

[[ -n "$PROJECT" ]] || { echo "ERROR: could not read project_id"; exit 1; }

log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "Project : $PROJECT"
log "Region  : $REGION"
log "Prefix  : $CLUSTER"
echo ""
echo "This will permanently delete GCP resources. Press Ctrl+C within 5 seconds to abort."
sleep 5

# ── 1. Cloud NAT (must be deleted before router) ─────────────────────────────
log "Deleting Cloud NAT..."
gcloud compute routers nats delete "${CLUSTER}-nat" \
  --router="${CLUSTER}-router" \
  --region="$REGION" \
  --project="$PROJECT" \
  --quiet 2>/dev/null && log "NAT deleted." || log "NAT not found — skipping."

# ── 2. Cloud Router ────────────────────────────────────────────────────────────
log "Deleting Cloud Router..."
gcloud compute routers delete "${CLUSTER}-router" \
  --region="$REGION" \
  --project="$PROJECT" \
  --quiet 2>/dev/null && log "Router deleted." || log "Router not found — skipping."

# ── 3. Firewall rules (must be deleted before VPC) ────────────────────────────
log "Deleting firewall rules..."
for rule in allow-internal allow-health-checks allow-iap; do
  gcloud compute firewall-rules delete "${CLUSTER}-${rule}" \
    --project="$PROJECT" \
    --quiet 2>/dev/null && log "  deleted ${CLUSTER}-${rule}" || log "  ${CLUSTER}-${rule} not found — skipping."
done

# ── 4. Subnet (must be deleted before VPC) ────────────────────────────────────
log "Deleting subnet..."
gcloud compute networks subnets delete "${CLUSTER}-nodes" \
  --region="$REGION" \
  --project="$PROJECT" \
  --quiet 2>/dev/null && log "Subnet deleted." || log "Subnet not found — skipping."

# ── 5. VPC ────────────────────────────────────────────────────────────────────
log "Deleting VPC..."
gcloud compute networks delete "${CLUSTER}-vpc" \
  --project="$PROJECT" \
  --quiet 2>/dev/null && log "VPC deleted." || log "VPC not found — skipping."

# ── 6. Service Accounts ───────────────────────────────────────────────────────
log "Deleting service accounts..."
for sa in nodes vault argocd eso; do
  EMAIL="${CLUSTER}-${sa}@${PROJECT}.iam.gserviceaccount.com"
  gcloud iam service-accounts delete "$EMAIL" \
    --project="$PROJECT" \
    --quiet 2>/dev/null && log "  deleted $EMAIL" || log "  $EMAIL not found — skipping."
done

# ── 7. Reset Terraform state to serial 0 ─────────────────────────────────────
log "Resetting Terraform state file..."
EMPTY_STATE='{"version":4,"terraform_version":"1.9.0","serial":0,"lineage":"","outputs":{},"resources":[],"check_results":null}'
echo "$EMPTY_STATE" | gcloud storage cp - \
  "gs://${PROJECT}-prod-gke-tfstate/prod-gke/state/default.tfstate" \
  --content-type="application/json" \
  --project="$PROJECT"
log "State reset."

echo ""
log "================================================================"
log "Cleanup complete. All orphaned resources removed."
log ""
log "Next:"
log "  terraform plan    # should show resources to CREATE"
log "  terraform apply"
log "================================================================"
