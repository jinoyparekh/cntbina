# GCP ↔ GitHub OIDC Bootstrap

Keyless auth between GitHub Actions and GCP using Workload Identity Federation.
No long-lived JSON keys. Terraform state lives in GCS.

---

## What the script creates

| Resource | Name |
|---|---|
| Workload Identity Pool | `github-actions-pool` |
| OIDC Provider | `github-actions-provider` |
| Terraform Service Account | `terraform-deployer@<project>.iam.gserviceaccount.com` |
| GCS State Bucket | `<project-id>-tfstate` |

**SA roles granted:** `compute.networkAdmin`, `compute.securityAdmin`, `container.admin`, `iam.roleAdmin`, `iam.serviceAccountAdmin`, `iam.serviceAccountUser`, `resourcemanager.projectIamAdmin`, `storage.admin`, `serviceusage.serviceUsageAdmin`

---

## Prerequisites

- `gcloud` CLI installed and authenticated (`gcloud auth login`)
- Your account has **Owner** or at minimum `roles/iam.workloadIdentityPoolAdmin` + `roles/iam.serviceAccountAdmin` + `roles/resourcemanager.projectIamAdmin`
- `gsutil` available (comes with gcloud SDK)

---

## Step 1 — Run the script

```bash
export PROJECT_ID="your-gcp-project-id"
export GITHUB_ORG="your-github-org"

# Optional: restrict to a single repo instead of the whole org
# export GITHUB_REPO="infra-repo"

export REGION="us-central1"   # region for TF state bucket

chmod +x scripts/setup-gcp-oidc.sh
./scripts/setup-gcp-oidc.sh
```

The script is **idempotent** — safe to re-run if it fails partway through.

At the end it prints three values you need for GitHub:

```
GCP_WORKLOAD_IDENTITY_PROVIDER   projects/<number>/locations/global/workloadIdentityPools/...
GCP_SERVICE_ACCOUNT              terraform-deployer@<project>.iam.gserviceaccount.com
TF_STATE_BUCKET                  <project-id>-tfstate
```

---

## Step 2 — GitHub: add secrets

Go to your GitHub org or repo → **Settings → Secrets and variables → Actions**.

Add these three **secrets** (or org-level secrets shared to the repo):

| Secret name | Value (from script output) |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/123.../providers/github-actions-provider` |
| `GCP_SERVICE_ACCOUNT` | `terraform-deployer@your-project.iam.gserviceaccount.com` |
| `TF_STATE_BUCKET` | `your-project-id-tfstate` |

> **Org secrets** → Settings (org level) → Secrets → Actions → New organization secret → grant access to the relevant repo(s).
>
> **Repo secrets** → Settings (repo level) → Secrets and variables → Actions → New repository secret.

---

## Step 3 — Terraform backend

In your Terraform root module add:

```hcl
terraform {
  backend "gcs" {
    bucket = "your-project-id-tfstate"   # or use -backend-config in CI
    prefix = "terraform/state"
  }
}
```

Or pass it dynamically in the workflow:

```bash
terraform init -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}"
```

---

## Step 4 — GitHub Actions workflow

Create `.github/workflows/terraform.yml`:

```yaml
name: Terraform

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read
  id-token: write   # REQUIRED for OIDC

jobs:
  terraform:
    name: Plan & Apply
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - id: auth
        name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.9"

      - name: Terraform Init
        run: terraform init -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}"
        working-directory: terraform/

      - name: Terraform Plan
        run: terraform plan -out=tfplan
        working-directory: terraform/

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan
        working-directory: terraform/
```

> Set `working-directory` to wherever your `.tf` files live.

---

## Verification

After the first successful workflow run, confirm it worked:

```bash
# Check the WIF pool and provider exist
gcloud iam workload-identity-pools list --location=global --project=$PROJECT_ID
gcloud iam workload-identity-pools providers list \
  --workload-identity-pool=github-actions-pool \
  --location=global --project=$PROJECT_ID

# Check SA exists and has correct bindings
gcloud iam service-accounts describe terraform-deployer@${PROJECT_ID}.iam.gserviceaccount.com

# Check state bucket
gsutil ls -L gs://${PROJECT_ID}-tfstate
```

In GitHub Actions, a successful auth step looks like:

```
Successfully created a credentials file for 'terraform-deployer@...'
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `roles/iam.workloadIdentityUser` denied | Re-run script; check `GITHUB_ORG` / `GITHUB_REPO` matches exactly |
| `iam.googleapis.com` not enabled | Script enables it; wait 30–60s after first run |
| Terraform state permission denied | SA needs `roles/storage.objectAdmin` on the bucket — re-run script |
| `id-token: write` missing | Add `permissions: id-token: write` to the job or top of workflow |
| Provider `attribute-condition` fails | Ensure `GITHUB_ORG` in script matches the org slug in the GitHub URL exactly |

---

## Security notes

- The attribute condition locks the OIDC token to your org (or specific repo if `GITHUB_REPO` is set). Tokens from other orgs/repos are rejected by GCP even if the JWT is valid.
- No JSON key is ever created or stored. Credentials are ephemeral per-job tokens.
- The state bucket has uniform bucket-level access and public access prevention enabled.
- Versioning on the state bucket allows rollback if state is corrupted.
