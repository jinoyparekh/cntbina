# cntbina — GCP Infrastructure

Infrastructure-as-code for deploying GCP resources (VPC, Subnets, Firewall, IAM) via GitHub Actions with keyless authentication. No long-lived service account keys are stored anywhere.

---

## Why this setup

| Problem | Solution |
|---|---|
| JSON keys in CI are a leak risk | Workload Identity Federation — GitHub's OIDC token exchanged for a short-lived GCP token per job |
| Manual infra changes are untraceable | All changes go through Terraform, reviewed in PRs, applied only on merge to `master` |
| Modules break silently | Native Terraform unit tests run on every push to `master`, gated before plan/apply |
| Credentials in state files | GCS backend with versioning, private bucket, SA-only access |

---

## Architecture

```
GitHub Actions
     │
     │  OIDC token (id-token: write)
     ▼
Workload Identity Federation
     │
     │  impersonate (no key, short-lived)
     ▼
terraform-deployer SA
     │
     ├── Terraform Init  ──►  GCS bucket (state)
     └── Terraform Apply ──►  GCP Project
                                  ├── VPC + Subnets
                                  ├── Firewall rules
                                  ├── IAM / Service Accounts
                                  └── GKE cluster (upcoming)
```

---

## Repository structure

```
.
├── .github/
│   └── workflows/
│       ├── module-tests.yml       # entry point: unit tests on push to master
│       └── terraform.yml          # plan + apply, triggered only after tests pass
├── scripts/
│   ├── setup-gcp-oidc.sh          # one-time bootstrap: WIF + SA + GCS bucket
│   └── README.md                  # step-by-step setup instructions
└── terraform/
    ├── versions.tf                # backend + provider config
    ├── variables.tf               # root inputs
    ├── main.tf                    # module composition
    ├── modules/
    │   ├── apis/                  # GCP API enablement
    │   ├── vpc/                   # VPC network
    │   ├── subnets/               # GKE subnets + secondary ranges
    │   ├── firewall/              # firewall rules (internal, GKE master, ASM, health checks)
    │   └── iam/                   # GKE node SA + security-tools Workload Identity SA
    └── tests/
        └── firewall_unit.tftest.hcl   # mock provider, no GCP creds needed
```

---

## Quick start

**1. Bootstrap GCP once** (see [scripts/README.md](scripts/README.md)):

```bash
export PROJECT_ID="your-gcp-project-id"
export GITHUB_ORG="your-github-org"
export GITHUB_REPO="your-repo-name"   # optional: restrict WIF to one repo
./scripts/setup-gcp-oidc.sh
```

**2. Add four GitHub Actions variables** (Settings → Secrets and variables → Actions → Variables):

| Variable | Value |
|---|---|
| `GCP_PROJECT_ID` | `your-gcp-project-id` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | printed by the script |
| `GCP_SERVICE_ACCOUNT` | printed by the script |
| `TF_STATE_BUCKET` | printed by the script |

**3. Push to `master`.** The pipeline runs automatically.

---

## CI/CD pipeline

Pushes to `master` trigger a two-workflow chain:

```
push → master
  └─▶ module-tests.yml        (all module unit tests, parallel, no GCP creds)
        ├── detect-modules
        ├── unit-test [module-a]
        ├── unit-test [module-b]  ...
        └── module-tests-complete
              │
              │ (only if all tests passed)
              ▼
          terraform.yml        (needs real GCP credentials)
              ├── plan
              └── apply
```

### `module-tests.yml` — unit tests

Runs automatically on every push to `master`. Detects all test files under `terraform/tests/`, runs each module's `*_unit.tftest.hcl` in parallel using a mock GCP provider — no credentials required. Can also be triggered manually to run a single module ad-hoc.

### `terraform.yml` — plan & apply

Triggered automatically by `workflow_run` only after `module-tests.yml` completes successfully. Never runs if any unit test fails. Can also be triggered manually via `workflow_dispatch` (plan or apply).

```
Push to master:   [tests pass] → plan → apply
Manual dispatch:  plan  (or apply if action=apply)
```

---

## Terraform modules

| Module | Path | What it creates |
|---|---|---|
| `apis` | `modules/apis` | Enables required GCP APIs |
| `vpc` | `modules/vpc` | VPC network |
| `subnets` | `modules/subnets` | GKE node/pod/service subnets with secondary ranges |
| `firewall` | `modules/firewall` | Firewall rules: internal, GKE master, ASM/Istio, health checks |
| `iam` | `modules/iam` | GKE node SA (least-privilege) + security-tools Workload Identity SA |

---

## Local development

```bash
cd terraform/

# init without backend (local state)
terraform init -backend=false

# run all unit tests (no GCP creds needed)
terraform test -filter=tests/firewall_unit.tftest.hcl

# plan against real GCP
terraform init -backend-config="bucket=<TF_STATE_BUCKET>"
terraform plan
```
