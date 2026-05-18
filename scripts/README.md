# GCP ↔ GitHub OIDC Bootstrap

Keyless auth between GitHub Actions and GCP via Workload Identity Federation. No JSON keys. Terraform state in GCS.

---

## What the script creates

| Resource | Name |
|---|---|
| Workload Identity Pool | `github-actions-pool` |
| OIDC Provider | `github-actions-provider` |
| Service Account | `terraform-deployer@<project>.iam.gserviceaccount.com` |
| GCS State Bucket | `<project-id>-tfstate` |

SA roles: `compute.networkAdmin`, `compute.securityAdmin`, `container.admin`, `iam.roleAdmin`, `iam.serviceAccountAdmin`, `iam.serviceAccountUser`, `resourcemanager.projectIamAdmin`, `storage.admin`, `serviceusage.serviceUsageAdmin`

---

## Prerequisites

- `gcloud` CLI authenticated (`gcloud auth login`)
- Your account has Owner or `iam.workloadIdentityPoolAdmin` + `iam.serviceAccountAdmin` + `resourcemanager.projectIamAdmin`

---

## Step 1 — Run the script

```bash
export PROJECT_ID="your-gcp-project-id"
export GITHUB_ORG="your-github-org"
# export GITHUB_REPO="infra-repo"   # optional: restrict to one repo instead of whole org
# export REGION="us-central1"       # default: us-central1

chmod +x scripts/setup-gcp-oidc.sh
./scripts/setup-gcp-oidc.sh
```

Idempotent — safe to re-run. At the end it prints the three values for Step 2.

---

## Step 2 — GitHub: add Actions variables

Go to **Settings → Secrets and variables → Actions → Variables** (not Secrets — these values are not sensitive).

| Variable name | Value (from script output) |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/123.../providers/github-actions-provider` |
| `GCP_SERVICE_ACCOUNT` | `terraform-deployer@your-project.iam.gserviceaccount.com` |
| `TF_STATE_BUCKET` | `your-project-id-tfstate` |

> Org-level: **Org Settings → Secrets and variables → Actions → Variables**, then grant access to the repo.

---

## Step 3 — Terraform backend

```hcl
terraform {
  backend "gcs" {
    bucket = "your-project-id-tfstate"
    prefix = "terraform/state"
  }
}
```

Or let the workflow pass it dynamically via `-backend-config` (already done in `.github/workflows/terraform.yml`).

---

## Step 4 — Push and trigger

The workflow at `.github/workflows/terraform.yml` runs on every push/PR to `main`:

- **PRs**: fmt check → validate → plan
- **Push to main**: fmt check → validate → plan → apply

Set `TF_DIR` in the workflow `env:` block if your `.tf` files are not in `terraform/`.

---

## Verification

```bash
# Pool and provider
gcloud iam workload-identity-pools providers list \
  --workload-identity-pool=github-actions-pool \
  --location=global --project=$PROJECT_ID

# State bucket
gsutil ls -L gs://${PROJECT_ID}-tfstate
```

A successful auth step in Actions shows:
```
Successfully created a credentials file for 'terraform-deployer@...'
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `workloadIdentityUser` denied | Re-run script; verify `GITHUB_ORG`/`GITHUB_REPO` match exactly |
| Terraform state permission denied | SA needs `storage.admin` at project level — re-run script |
| `id-token: write` missing | Already set in the workflow `permissions` block |
| Provider attribute-condition fails | `GITHUB_ORG` must match the GitHub org slug exactly (case-sensitive) |
| Sandbox bucket IAM warning | Expected — project-level `storage.admin` covers it |
