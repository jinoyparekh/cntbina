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

SA roles granted at project level: `compute.networkAdmin`, `compute.securityAdmin`, `container.admin`, `iam.roleAdmin`, `iam.serviceAccountAdmin`, `iam.serviceAccountUser`, `resourcemanager.projectIamAdmin`, `storage.admin`, `serviceusage.serviceUsageAdmin`

SA role granted on the state bucket: `storage.objectAdmin`

---

## Prerequisites

- `gcloud` CLI installed and authenticated (`gcloud auth login`)
- Your account has **Owner** or all of: `iam.workloadIdentityPoolAdmin` + `iam.serviceAccountAdmin` + `resourcemanager.projectIamAdmin` + `storage.admin`

---

## Step 1 — Run the script

```bash
export PROJECT_ID="your-gcp-project-id"
export GITHUB_ORG="your-github-org"
# export GITHUB_REPO="infra-repo"   # optional: restrict WIF to one repo instead of whole org
# export REGION="us-central1"       # default: us-central1

chmod +x scripts/setup-gcp-oidc.sh
./scripts/setup-gcp-oidc.sh
```

Idempotent — safe to re-run. At the end it prints the four values needed for Step 2.

If any IAM binding fails (e.g. insufficient caller permissions), the script prints the exact `gcloud` commands to re-run as an Owner rather than exiting silently.

---

## Step 2 — GitHub: add Actions variables

Go to **Settings → Secrets and variables → Actions → Variables** (not Secrets — these values are not sensitive).

| Variable name | Value (from script output) |
|---|---|
| `GCP_PROJECT_ID` | `your-gcp-project-id` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/123.../providers/github-actions-provider` |
| `GCP_SERVICE_ACCOUNT` | `terraform-deployer@your-project.iam.gserviceaccount.com` |
| `TF_STATE_BUCKET` | `your-project-id-tfstate` |

> Org-level: **Org Settings → Secrets and variables → Actions → Variables**, then grant access to the repo.

---

## Step 3 — Push to master

The pipeline triggers automatically:

```
push → master
  └─▶ module-tests.yml   (unit tests, no GCP creds)
        └─▶ terraform.yml  (plan + apply, only if tests pass)
```

No manual trigger needed. `terraform.yml` is blocked by `workflow_run` and will not run if any unit test fails.

---

## Verification

```bash
# Check pool and provider exist
gcloud iam workload-identity-pools providers list \
  --workload-identity-pool=github-actions-pool \
  --location=global --project=$PROJECT_ID

# Check state bucket and its IAM
gcloud storage ls --buckets "gs://${PROJECT_ID}-tfstate"
gcloud storage buckets get-iam-policy "gs://${PROJECT_ID}-tfstate"
```

A successful auth step in GitHub Actions shows:
```
Successfully created a credentials file for 'terraform-deployer@...'
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `workloadIdentityUser` denied | Re-run script; verify `GITHUB_ORG`/`GITHUB_REPO` match exactly (case-sensitive) |
| `storage.objects.list` denied at init | SA is missing `storage.objectAdmin` on the state bucket — run the bucket IAM command printed by the script |
| `id-token: write` missing | Already set in the workflow `permissions` block — check you haven't overridden it |
| Provider attribute-condition fails | `GITHUB_ORG` must match the GitHub org slug exactly |
| IAM bindings silently skipped | Script now prints failed bindings explicitly — re-run as project Owner |
| Sandbox: IAM commands fail | Expected — Pluralsight/ACG sandboxes block all IAM changes. Run the script in a real GCP project as Owner |
