# Remote State Configuration (GCS)
#
# Before running `terraform init`, create the GCS bucket:
#   gsutil mb -p <project-id> -l <region> gs://<project-id>-prod-gke-tfstate
#   gcloud storage buckets update gs://<project-id>-prod-gke-tfstate \
#     --versioning --uniform-bucket-level-access
#
# Then uncomment this block and replace the bucket name:

# terraform {
#   backend "gcs" {
#     bucket = "<project-id>-prod-gke-tfstate"
#     prefix = "prod-gke/state"
#   }
# }
