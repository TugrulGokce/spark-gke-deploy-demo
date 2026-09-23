# Spark on GKE Deployment Demo

This project demonstrates how to deploy and automate an Apache Spark application on Google Kubernetes Engine (GKE).

The main goal is to show the end-to-end deployment workflow of a Spark application using Kubernetes, GitHub Actions, Argo CD, and the Kubeflow Spark Operator.

## Architecture

The project uses:

- Apache Spark 4.0.3
- Scala 2.13
- Google Kubernetes Engine (GKE)
- Google Cloud Storage (GCS)
- Google Artifact Registry
- Kubeflow Spark Operator
- GitHub Actions
- Argo CD
- Terraform
- DataFlint

## Project Flow

The Spark application reads Parquet data from GCS, processes the data, and writes the results back to GCS.

The deployment workflow includes:

1. Provisioning the infrastructure with Terraform.
2. Building the Scala Spark application with `sbt assembly`.
3. Building and publishing the Spark Docker image to Artifact Registry.
4. Running the Spark application on GKE using the Kubeflow Spark Operator.
5. Automating image builds and manifest updates with GitHub Actions.
6. Synchronizing Kubernetes manifests with GKE using Argo CD.
7. Observing completed Spark jobs with DataFlint.

## Repository Structure

```text
.
├── .github/workflows/    # GitHub Actions CI workflow
├── k8s/                  # SparkApplication and DataFlint manifests
├── scripts/              # Helper scripts such as WIF setup
├── src/                  # Scala Spark application
├── terraform/            # GCP and Kubernetes infrastructure
├── Dockerfile
└── build.sbt
```

## Main Spark Application

The demo application reads completed orders from GCS, ranks the most recent orders for each customer, and writes the result back to GCS as Parquet files.

## CI/CD and GitOps

GitHub Actions builds the application JAR and Docker image, pushes the image to Artifact Registry, and updates the image version in the `SparkApplication` manifest.

Argo CD monitors the Kubernetes manifests stored in Git and synchronizes changes with the GKE cluster.

## Observability

Spark event logs are stored in GCS and analyzed through the DataFlint History Server.

This allows completed Spark applications to be inspected using stage, task, executor, SQL, and performance information.

## Article

A detailed walkthrough of the project is available in the accompanying Medium article.

> Medium link. Not yet :)