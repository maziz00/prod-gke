#!/bin/bash
# -----------------------------------------------------------------------------
# Script to Bootstrap ArgoCD for GitOps on the newly created GKE Cluster
# -----------------------------------------------------------------------------

set -e

# --- Configuration ---
ARGOCD_VERSION="v2.8.4"
NAMESPACE="argocd"

echo "=== Bootstrapping GitOps (ArgoCD) ==="

# 1. Connect to cluster (ensure you have authenticated with gcloud)
# Assumes terraform output has cluster name and region.
# If not running in pipeline, pass arguments.
CLUSTER_NAME=$1
REGION=$2

if [ -z "$CLUSTER_NAME" ] || [ -z "$REGION" ]; then
    echo "Usage: $0 <CLUSTER_NAME> <REGION>"
    exit 1
fi

echo "Connecting to cluster $CLUSTER_NAME in $REGION..."
gcloud container clusters get-credentials "$CLUSTER_NAME" --region "$REGION"

# 2. Install ArgoCD
echo "Creating namespace $NAMESPACE..."
kubectl create namespace "$NAMESPACE" || echo "Namespace $NAMESPACE already exists"

echo "Applying ArgoCD manifest (High Availability version for Production)..."
kubectl apply -n "$NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/ha/install.yaml

# 3. Wait for ArgoCD to be ready
echo "Waiting for ArgoCD components to be ready..."
kubectl wait --for=condition=available deployment -l "app.kubernetes.io/name=argocd-server" -n "$NAMESPACE" --timeout=300s

# 4. Get Initial Admin Password
PASSWORD=$(kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "----------------------------------------------------------------"
echo "✅ ArgoCD Installed Successfully!"
echo "Server Service: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Username: admin"
echo "Password: $PASSWORD"
echo "----------------------------------------------------------------"
