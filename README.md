# cntbina — GCP Infrastructure

Infrastructure-as-code for deploying GCP resources (VPC, IAM, Subnets, GKE) via GitHub Actions with keyless authentication. No long-lived service account keys are stored anywhere.

---

## Why this setup

| Problem | Solution |
|---|---|
| JSON keys in CI are a leak risk | Workload Identity Federation — GitHub's OIDC token exchanged for a short-lived GCP token per job |
| Manual infra changes are untraceable | All changes go through Terraform, reviewed in PRs, applied only on merge to `main` |
| Modules break silently | Native Terraform unit tests run on every PR, gated before plan/apply |
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
                                  ├── Cloud NAT
                                  ├── IAM bindings
                                  └── GKE cluster (upcoming)
```

---

## Repository structure

```
.
├── .github/
│   └── workflows/
│       ├── terraform.yml          # plan on PR, apply on merge to main
│       └── module-tests.yml       # per-module unit tests on module/test changes
├── scripts/
│   ├── setup-gcp-oidc.sh          # one-time bootstrap: WIF + SA + GCS bucket
│   └── README.md                  # step-by-step setup instructions
└── terraform/
    ├── versions.tf                # backend + provider config
    ├── variables.tf               # root inputs
    ├── main.tf                    # module composition
    ├── outputs.tf                 # root outputs
    ├── terraform.tfvars.example   # copy → terraform.tfvars for local use
    ├── modules/
    │   └── vpc/                   # VPC, subnets, firewall, NAT
    └── tests/
        ├── vpc_unit.tftest.hcl        # mock provider, no GCP needed
        └── vpc_integration.tftest.hcl # real plan+apply against GCP
```

---

## Quick start

**1. Bootstrap GCP once** (see [scripts/README.md](scripts/README.md)):

```bash
export PROJECT_ID="your-gcp-project-id"
export GITHUB_ORG="your-github-org"
./scripts/setup-gcp-oidc.sh
```

**2. Add four GitHub Actions variables** (Settings → Secrets and variables → Actions → Variables):

| Variable | Value |
|---|---|
| `GCP_PROJECT_ID` | `your-gcp-project-id` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | printed by the script |
| `GCP_SERVICE_ACCOUNT` | printed by the script |
| `TF_STATE_BUCKET` | printed by the script |

**3. Copy and fill in tfvars for local work:**

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# edit terraform.tfvars with your values
```

**4. Push.** PRs get a plan; merges to `main` apply.

---

## CI/CD pipelines

### `module-tests.yml` — per-module unit tests

Triggers only when `terraform/modules/**` or `terraform/tests/**` changes. Detects which modules changed and runs only those tests in parallel. Uses a mock GCP provider — no credentials required, runs on every PR in seconds.

### `terraform.yml` — plan & apply

Triggers on all PRs and pushes to `main`. Unit tests must pass before this job runs. Applies only on merge to `main`.

```
PR:    unit-tests → fmt check → validate → plan
main:  unit-tests → fmt check → validate → plan → apply
```

---

## Terraform modules

| Module | Path | What it creates |
|---|---|---|
| `vpc` | `modules/vpc` | VPC network, regional subnet with GKE secondary ranges, internal firewall, health-check firewall, Cloud Router, Cloud NAT |

---

## Local development

```bash
cd terraform/

# init without backend (local state)
terraform init -backend=false

# run unit tests (no GCP creds needed)
terraform test -filter=tests/vpc_unit.tftest.hcl

# plan against real GCP
terraform init -backend-config="bucket=<TF_STATE_BUCKET>"
terraform plan
```
