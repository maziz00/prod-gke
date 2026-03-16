#!/bin/bash
# bootstrap-argocd.sh — Install ArgoCD via Helm and apply the App-of-Apps root application.
#
# Run this ONCE after `terraform apply` completes.
# Everything after this point is managed by ArgoCD.
#
# Prerequisites:
#   - kubectl configured for the target cluster (run scripts/get-credentials.sh first)
#   - helm >= 3.12
#   - argocd CLI (optional, for initial password retrieval)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ARGOCD_VERSION="${ARGOCD_VERSION:-7.5.x}"
ARGOCD_NAMESPACE="argocd"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# --- Validate prerequisites ---
for cmd in kubectl helm; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not installed." >&2
    exit 1
  fi
done

log "Installing ArgoCD ${ARGOCD_VERSION} in namespace ${ARGOCD_NAMESPACE}..."

helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update argo

helm upgrade --install argocd argo/argo-cd \
  --namespace "${ARGOCD_NAMESPACE}" \
  --create-namespace \
  --version "${ARGOCD_VERSION}" \
  --set server.service.type=ClusterIP \
  --set "controller.tolerations[0].key=CriticalAddonsOnly" \
  --set "controller.tolerations[0].operator=Exists" \
  --set "server.tolerations[0].key=CriticalAddonsOnly" \
  --set "server.tolerations[0].operator=Exists" \
  --wait \
  --timeout 10m

log "ArgoCD pods:"
kubectl get pods -n "${ARGOCD_NAMESPACE}"

log "Applying App-of-Apps root application..."
kubectl apply -f "${ROOT_DIR}/gitops/argocd/apps/root-app.yaml"

log "Retrieving initial admin password..."
ARGOCD_PASSWORD=$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode)

log "================================================================"
log "ArgoCD is ready!"
log ""
log "Access ArgoCD UI (port-forward):"
log "  kubectl port-forward svc/argocd-server -n ${ARGOCD_NAMESPACE} 8080:443"
log "  Open: https://localhost:8080  (accept the self-signed cert warning)"
log ""
log "Access ArgoCD UI (production via Istio):"
log "  Update gitops/apps/argocd/argocd-ingress.yaml with your real hostname."
log "  Point DNS to: kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
log "  Username: admin"
log "  Password: ${ARGOCD_PASSWORD}"
log ""
log "The root Application is syncing. Watch progress:"
log "  kubectl get applications -n ${ARGOCD_NAMESPACE}"
log "================================================================"
