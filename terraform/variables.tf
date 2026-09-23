variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region (parent of the cluster zone; also used for GCS bucket)."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the zonal GKE cluster (free-tier friendly)."
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "GKE cluster name."
  type        = string
  default     = "spark-demo"
}

variable "node_machine_type" {
  description = "Node machine type. e2-medium: 2 vCPU, 4GB — fits Spark driver + one small executor per node."
  type        = string
  default     = "e2-medium"
}

variable "node_count" {
  description = "Number of nodes in the pool."
  type        = number
  default     = 2
}

variable "node_disk_size_gb" {
  description = "Boot disk size per node."
  type        = number
  default     = 30
}

variable "data_bucket_name" {
  description = "GCS bucket for the mock e-commerce dataset. Must be globally unique."
  type        = string
}

variable "mock_data_dir" {
  description = "Local path to the mock-data project (holds generate.py)."
  type        = string
  default     = "../mock-data"
}

variable "spark_namespace" {
  description = "Kubernetes namespace where Spark driver+executor pods run."
  type        = string
  default     = "spark"
}

variable "spark_ksa_name" {
  description = "Kubernetes ServiceAccount used by Spark driver pods."
  type        = string
  default     = "spark"
}
