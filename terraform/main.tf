provider "google" {
  project = var.project_id
  region  = var.region
}

# Access token used by the Kubernetes provider to authenticate to the cluster
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.this.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.this.master_auth[0].cluster_ca_certificate)
}

# GCP APIs required for GKE, GCS and Artifact Registry
resource "google_project_service" "required" {
  for_each = toset([
    "container.googleapis.com",
    "compute.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "artifactregistry.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
