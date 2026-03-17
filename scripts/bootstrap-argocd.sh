#!/bin/bash
# bootstrap-argocd.sh — Bootstrap platform dependencies, then hand off to ArgoCD GitOps.
#
# Run this ONCE after `terraform apply` completes. Order:
#   1. Istio (base CRDs → istiod → ingress gateway)
#   2. ArgoCD
#   3. App-of-Apps root Application → ArgoCD manages everything from here
#
# Istio and ArgoCD are bootstrapped manually because ArgoCD cannot sync resources
# that depend on CRDs (PeerAuthentication, VirtualService, Gateway) before those
# CRDs exist. The same pattern as ArgoCD itself — bootstrap once, GitOps takes over.
#
# Prerequisites:
#   - kubectl configured for the target cluster (run scripts/get-credentials.sh first)
#   - helm >= 3.12

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ARGOCD_VERSION="${ARGOCD_VERSION:-7.5.x}"
ISTIO_VERSION="${ISTIO_VERSION:-1.22.3}"
ARGOCD_NAMESPACE="argocd"
ISTIO_NAMESPACE="istio-system"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# --- Validate prerequisites ---
for cmd in kubectl helm; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not installed." >&2
    exit 1
  fi
done

# ============================================================
# PHASE 1 — Istio
# Must complete before ArgoCD applies any Istio-dependent resources.
# ============================================================
log "Adding Helm repos..."
helm repo add argo   https://argoproj.github.io/argo-helm               --force-update
helm repo add istio  https://istio-release.storage.googleapis.com/charts --force-update
helm repo update

log "--- Phase 1: Istio ${ISTIO_VERSION} ---"

log "Installing istio-base (CRDs)..."
helm upgrade --install istio-base istio/base \
  --namespace "${ISTIO_NAMESPACE}" \
  --create-namespace \
  --version "${ISTIO_VERSION}" \
  --wait --timeout 5m

log "Installing istiod (control plane)..."
helm upgrade --install istiod istio/istiod \
  --namespace "${ISTIO_NAMESPACE}" \
  --version "${ISTIO_VERSION}" \
  --set global.meshID=prod-gke-mesh \
  --set global.network=prod-gke-network \
  --set meshConfig.accessLogFile=/dev/stdout \
  --set meshConfig.enableAutoMtls=true \
  --wait --timeout 5m

log "Installing istio-ingressgateway..."
helm upgrade --install istio-ingressgateway istio/gateway \
  --namespace "${ISTIO_NAMESPACE}" \
  --version "${ISTIO_VERSION}" \
  --set service.type=LoadBalancer \
  --set autoscaling.enabled=true \
  --set autoscaling.minReplicas=2 \
  --set autoscaling.maxReplicas=5 \
  --wait --timeout 5m

log "Istio pods:"
kubectl get pods -n "${ISTIO_NAMESPACE}"

# ============================================================
# PHASE 2 — ArgoCD
# ============================================================
log "--- Phase 2: ArgoCD ${ARGOCD_VERSION} ---"

helm upgrade --install argocd argo/argo-cd \
  --namespace "${ARGOCD_NAMESPACE}" \
  --create-namespace \
  --version "${ARGOCD_VERSION}" \
  --set server.service.type=ClusterIP \
  --set redis.networkPolicy.create=false \
  --set "controller.tolerations[0].key=CriticalAddonsOnly" \
  --set "controller.tolerations[0].operator=Exists" \
  --set "server.tolerations[0].key=CriticalAddonsOnly" \
  --set "server.tolerations[0].operator=Exists" \
  --wait --timeout 10m

log "ArgoCD pods:"
kubectl get pods -n "${ARGOCD_NAMESPACE}"

# ============================================================
# PHASE 3 — App-of-Apps
# ArgoCD takes over all further management from this point.
# ============================================================
log "--- Phase 3: Applying App-of-Apps root Application ---"
kubectl apply -f "${ROOT_DIR}/gitops/argocd/apps/root-app.yaml"

log "Retrieving initial admin password..."
ARGOCD_PASSWORD=$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode)

log "================================================================"
log "Bootstrap complete!"
log ""
log "Access ArgoCD UI (port-forward):"
log "  kubectl port-forward svc/argocd-server -n ${ARGOCD_NAMESPACE} 8080:443"
log "  Open: https://localhost:8080  (accept the self-signed cert warning)"
log ""
log "Access ArgoCD UI (production via Istio):"
log "  Update gitops/apps/argocd/argocd-ingress.yaml with your real hostname."
log "  Ingress gateway IP:"
log "    kubectl get svc istio-ingressgateway -n ${ISTIO_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
log "  Username: admin"
log "  Password: ${ARGOCD_PASSWORD}"
log ""
log "Watch ArgoCD sync progress:"
log "  kubectl get applications -n ${ARGOCD_NAMESPACE} -w"
log "================================================================"
