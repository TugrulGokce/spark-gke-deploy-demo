#!/usr/bin/env bash
set -euo pipefail

ACCOUNT="<your-account-mail>"
PROJECT_ID="<your-project-id>"

REPO="TugrulGokce/spark-gke-deploy-demo"
POOL_NAME="github-actions-pool"
PROVIDER_NAME="github-provider"
SA_NAME="github-actions-ci"
AR_REPOSITORY="spark"
AR_LOCATION="us-central1"

# authenticate as yourself and target the right project before running anything below
gcloud config set account "$ACCOUNT"
gcloud config set project "$PROJECT_ID"

echo "Enabling required Google Cloud APIs..."
gcloud services enable \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  --project="$PROJECT_ID"

echo "[1/7] Creating GitHub Actions CI Service Account..."
gcloud iam service-accounts create "$SA_NAME" \
  --project="$PROJECT_ID" \
  --display-name="GitHub Actions CI"

echo "[2/7] Creating Workload Identity Pool..."
gcloud iam workload-identity-pools create "$POOL_NAME" \
  --project="$PROJECT_ID" \
  --location="global" \
  --display-name="GitHub Actions"

echo "[3/7] Getting Workload Identity Pool resource name..."
WORKLOAD_IDENTITY_POOL_ID=$(gcloud iam workload-identity-pools describe "$POOL_NAME" \
  --project="$PROJECT_ID" \
  --location="global" \
  --format="value(name)")

echo "[4/7] Creating GitHub OIDC Provider..."
gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_NAME" \
  --project="$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="$POOL_NAME" \
  --display-name="GitHub OIDC" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='$REPO'" \
  --issuer-uri="https://token.actions.githubusercontent.com"

echo "[5/7] Granting Artifact Registry Writer role to CI Service Account..."
gcloud artifacts repositories add-iam-policy-binding "$AR_REPOSITORY" \
  --project="$PROJECT_ID" \
  --location="$AR_LOCATION" \
  --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

echo "[6/7] Allowing GitHub repository to impersonate the CI Service Account..."
gcloud iam service-accounts add-iam-policy-binding \
  "${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="$PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_POOL_ID}/attribute.repository/${REPO}"

echo "[7/7] Getting Workload Identity Provider resource name..."
WIF_PROVIDER=$(gcloud iam workload-identity-pools providers describe "$PROVIDER_NAME" \
  --project="$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="$POOL_NAME" \
  --format="value(name)")