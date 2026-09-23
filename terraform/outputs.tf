output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.this.name
}

output "cluster_location" {
  description = "GKE cluster region/zone."
  value       = google_container_cluster.this.location
}

output "kubectl_config_command" {
  description = "Fetch kubeconfig credentials for kubectl."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.this.name} --zone ${google_container_cluster.this.location} --project ${var.project_id}"
}

output "data_bucket" {
  description = "GCS bucket holding the mock e-commerce parquet dataset (under gs://<bucket>/raw/)."
  value       = google_storage_bucket.data.name
}

output "spark_namespace" {
  description = "Namespace for Spark driver+executor pods."
  value       = kubernetes_namespace.spark.metadata[0].name
}

output "spark_ksa" {
  description = "Kubernetes ServiceAccount to pass to spark-submit."
  value       = kubernetes_service_account.spark.metadata[0].name
}

# The Kubernetes API server URL is only known after kubeconfig is set up, so a command is returned instead
output "k8s_master_url_hint" {
  description = "Command to get k8s API server URL for spark-submit --master k8s://..."
  value       = "kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'"
}

output "scale_down_command" {
  description = "Scale the node pool to zero when not using the cluster (keeps cluster alive, cuts compute cost)."
  value       = "gcloud container clusters resize ${google_container_cluster.this.name} --node-pool primary --num-nodes=0 --zone ${google_container_cluster.this.location} --project ${var.project_id} --quiet"
}

output "scale_up_command" {
  description = "Scale the node pool back up before running Spark jobs."
  value       = "gcloud container clusters resize ${google_container_cluster.this.name} --node-pool primary --num-nodes=${var.node_count} --zone ${google_container_cluster.this.location} --project ${var.project_id} --quiet"
}
