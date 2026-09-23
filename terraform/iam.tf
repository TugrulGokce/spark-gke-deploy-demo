# ---------- Artifact Registry ----------

# Docker repository that stores the Spark job images built by CI
# GKE nodes pull the images from here when the driver and executor pods start
resource "google_artifact_registry_repository" "spark" {
  location      = var.region
  repository_id = "spark"
  format        = "DOCKER"

  depends_on = [google_project_service.required]
}

# ---------- GKE node service account (least privilege) ----------
# GKE nodes use a dedicated service account instead of the default Compute Engine one,
# which is granted broad project-level permissions (Editor role) by default.
# Only the permissions listed below are given to the nodes.

resource "google_service_account" "gke_nodes" {
  account_id   = "gke-nodes"
  display_name = "GKE node service account (least privilege)"
}

# Minimum permissions a node needs to run: writing logs, sending metrics and monitoring data
resource "google_project_iam_member" "gke_nodes_default" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Image pull access, bound to the Spark repository only instead of the whole project
# This is a separate binding because defaultNodeServiceAccount does not include Artifact Registry read access
resource "google_artifact_registry_repository_iam_member" "gke_nodes_spark_pull" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.spark.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ---------- Spark namespace ----------

# Namespace that isolates the Spark driver and executor pods from other workloads
# It is created after the node pool, since the Kubernetes API is only reachable once the cluster has nodes
resource "kubernetes_namespace" "spark" {
  metadata {
    name = var.spark_namespace
  }

  depends_on = [google_container_node_pool.primary]
}

# ---------- Google service account (GSA) for Spark ----------

# GCP identity that Spark pods act as when they call Google Cloud APIs (GCS in this project)
resource "google_service_account" "spark" {
  account_id   = "spark-workload"
  display_name = "Spark on GKE workload identity"
}

# Read and write access to the data bucket
# Spark reads the raw data from it and writes the processed output and event logs back to it
resource "google_storage_bucket_iam_member" "spark_bucket" {
  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.spark.email}"
}

# ---------- Kubernetes service account (KSA) for Spark ----------

# Kubernetes identity that the Spark driver and executor pods run with
# The annotation points to the GSA above, which tells GKE which Google identity this KSA maps to
resource "kubernetes_service_account" "spark" {
  metadata {
    name      = var.spark_ksa_name
    namespace = kubernetes_namespace.spark.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.spark.email
    }
  }
}

# ---------- Workload Identity binding (KSA -> GSA) ----------

# Completes the link between the two identities. The annotation on the KSA alone is not enough:
# the GSA must also allow that specific KSA (<namespace>/<ksa-name>) to impersonate it.
# With both sides in place, Spark pods authenticate to GCS without any JSON key files.
resource "google_service_account_iam_member" "spark_wi" {
  service_account_id = google_service_account.spark.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.spark_namespace}/${var.spark_ksa_name}]"

  # The Workload Identity pool (<project>.svc.id.goog) is only created together with the cluster,
  # so this binding has to wait for it
  depends_on = [google_container_cluster.this]
}

# ---------- RBAC for the Spark driver ----------
# In cluster mode the driver creates and monitors its own executor pods through the Kubernetes API,
# so the Spark KSA needs permissions on these resources inside the Spark namespace.
# https://spark.apache.org/docs/latest/running-on-kubernetes.html#rbac
#
# "deletecollection" is included on purpose. When the job finishes, Spark cleans up its resources
# with a delete request that uses a label selector, which the API server treats as deletecollection
# rather than delete. Without it the cleanup fails with a forbidden error.

resource "kubernetes_role" "spark_driver" {
  metadata {
    name      = "spark-driver"
    namespace = kubernetes_namespace.spark.metadata[0].name
  }

  # Executor pods
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch", "create", "delete", "deletecollection"]
  }

  # Driver service, used by executors to reach the driver and by the Spark UI
  rule {
    api_groups = [""]
    resources  = ["services"]
    verbs      = ["get", "list", "watch", "create", "delete", "deletecollection"]
  }

  # Configmaps that Spark generates for the executors (Spark configuration, pod templates)
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list", "watch", "create", "delete", "deletecollection", "update"]
  }

  # Persistent volume claims for executors that use volumes
  rule {
    api_groups = [""]
    resources  = ["persistentvolumeclaims"]
    verbs      = ["get", "list", "watch", "create", "delete", "deletecollection"]
  }
}

# Attaches the driver role to the Spark KSA, scoped to the Spark namespace
resource "kubernetes_role_binding" "spark_driver" {
  metadata {
    name      = "spark-driver"
    namespace = kubernetes_namespace.spark.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.spark_driver.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.spark.metadata[0].name
    namespace = kubernetes_namespace.spark.metadata[0].name
  }
}
