# GCS bucket for mock e-commerce data and Spark event logs
resource "google_storage_bucket" "data" {
  name                        = var.data_bucket_name
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = true

  # Demo data is temporary, so objects older than 30 days are removed
  lifecycle_rule {
    condition {
      age = 30
    }

    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.required]
}

# Generates the mock Parquet dataset locally and uploads it to the raw/ prefix
resource "null_resource" "seed_data" {
  triggers = {
    bucket        = google_storage_bucket.data.name
    generator_sha = filesha256("${path.module}/${var.mock_data_dir}/generate.py")
  }

  # Installs the required Python packages and generates the mock dataset
  provisioner "local-exec" {
    working_dir = "${path.module}/${var.mock_data_dir}"
    command     = "python -m pip install -q -r requirements.txt && python generate.py --out ./output"
  }

  # Uploads the generated Parquet files to GCS
  provisioner "local-exec" {
    command = "gsutil -m rsync -r ${path.module}/${var.mock_data_dir}/output gs://${google_storage_bucket.data.name}/raw/"
  }

  depends_on = [google_storage_bucket.data]
}

# Creates the spark-events prefix before Spark starts writing event logs
resource "google_storage_bucket_object" "spark_events_placeholder" {
  name    = "spark-events/.keep"
  bucket  = google_storage_bucket.data.name
  content = " "

  depends_on = [google_storage_bucket.data]
}
