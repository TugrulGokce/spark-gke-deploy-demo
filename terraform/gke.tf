# Zonal Standard cluster
# The free tier waives the management fee for one zonal cluster per billing account (Autopilot is not eligible)
resource "google_container_cluster" "this" {
  name     = var.cluster_name
  location = var.zone

  # Removes the default node pool in favor of the custom one defined below
  remove_default_node_pool = true
  initial_node_count       = 1

  # Workload Identity for pod-to-GCP authentication without JSON keys
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false

  depends_on = [google_project_service.required]
}

# On-demand nodes instead of spot, to avoid preemption during tests and demos
# The cluster is destroyed when not in use, so billed hours stay low anyway
resource "google_container_node_pool" "primary" {
  name     = "primary"
  location = var.zone
  cluster  = google_container_cluster.this.name

  node_count = var.node_count

  node_config {
    machine_type = var.node_machine_type
    disk_size_gb = var.node_disk_size_gb
    disk_type    = "pd-standard"
    spot         = false

    # Dedicated node service account (least privilege)
    # The default Compute Engine one cannot read from Artifact Registry
    service_account = google_service_account.gke_nodes.email

    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Binds the node role before nodes start, so the first image pull is already permitted
  depends_on = [google_project_iam_member.gke_nodes_default]
}
