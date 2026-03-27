#!/bin/bash

# This script creates secrets in Google Secret Manager.
# It prompts the user for the value of each secret.

# The GCP project ID is required as the first argument.
if [ -z "$1" ]; then
  echo "Usage: $0 <gcp-project-id>"
  exit 1
fi
GCP_PROJECT_ID=$1

# List of secret names to create
SECRET_NAMES=(
  "grafana-admin-credentials"
  "alertmanager-slack-webhook"
)

for secret_name in "${SECRET_NAMES[@]}"; do
  echo -n "Enter value for secret '$secret_name': "
  read -s secret_value
  echo

  # Create the secret if it doesn't exist
  gcloud secrets create "$secret_name" --project="$GCP_PROJECT_ID" --replication-policy="automatic" &>/dev/null
  if [ $? -eq 0 ]; then
    echo "Secret '$secret_name' created."
  else
    echo "Secret '$secret_name' already exists or there was an error."
  fi

  # Add a new version to the secret
  echo -n "$secret_value" | gcloud secrets versions add "$secret_name" --project="$GCP_PROJECT_ID" --data-file=-
  if [ $? -eq 0 ]; then
    echo "New version added to secret '$secret_name'."
  else
    echo "Failed to add new version to secret '$secret_name'."
  fi
  echo "--------------------"
done

echo "All secrets processed."
