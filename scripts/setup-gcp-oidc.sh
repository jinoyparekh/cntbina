#!/usr/bin/env bash
# setup-gcp-oidc.sh
# Wires GitHub Actions → GCP Workload Identity Federation for keyless Terraform deploys.
# Idempotent: safe to re-run.
set -euo pipefail

# ─── REQUIRED CONFIG ──────────────────────────────────────────────────────────
PROJECT_ID="${PROJECT_ID:-}"          # e.g. my-gcp-project-123
GITHUB_ORG="${GITHUB_ORG:-}"          # e.g. my-github-org
GITHUB_REPO="${GITHUB_REPO:-}"        # e.g. infra-repo  (leave empty = all org repos)
REGION="${REGION:-us-central1}"

# ─── DERIVED / FIXED NAMES ────────────────────────────────────────────────────
POOL_ID="github-actions-pool"
PROVIDER_ID="github-actions-provider"
SA_NAME="terraform-deployer"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
TF_BUCKET="${PROJECT_ID}-tfstate"

# ─── COLOURS ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ─── VALIDATION ───────────────────────────────────────────────────────────────
[[ -z "$PROJECT_ID"  ]] && die "PROJECT_ID is not set. Export it or edit this script."
[[ -z "$GITHUB_ORG"  ]] && die "GITHUB_ORG is not set. Export it or edit this script."

command -v gcloud >/dev/null 2>&1 || die "gcloud CLI not found."

info "Project  : $PROJECT_ID"
info "GitHub   : ${GITHUB_ORG}${GITHUB_REPO:+/${GITHUB_REPO}}"
info "Region   : $REGION"
echo ""

# ─── ACTIVE PROJECT ───────────────────────────────────────────────────────────
gcloud config set project "$PROJECT_ID" --quiet
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
info "Project number: $PROJECT_NUMBER"

# ─── ENABLE APIS ──────────────────────────────────────────────────────────────
info "Enabling required APIs..."
APIS=(
  iam.googleapis.com
  iamcredentials.googleapis.com
  cloudresourcemanager.googleapis.com
  sts.googleapis.com
  compute.googleapis.com
  container.googleapis.com
  storage.googleapis.com
  serviceusage.googleapis.com
)
gcloud services enable "${APIS[@]}" --project="$PROJECT_ID" --quiet
success "APIs enabled."

# ─── WORKLOAD IDENTITY POOL ───────────────────────────────────────────────────
info "Creating Workload Identity Pool: $POOL_ID ..."
if gcloud iam workload-identity-pools describe "$POOL_ID" \
     --location="global" --project="$PROJECT_ID" &>/dev/null; then
  warn "Pool '$POOL_ID' already exists — skipping creation."
else
  gcloud iam workload-identity-pools create "$POOL_ID" \
    --project="$PROJECT_ID" \
    --location="global" \
    --display-name="GitHub Actions Pool" \
    --description="Keyless auth for GitHub Actions" \
    --quiet
  success "Pool created."
fi

# ─── WORKLOAD IDENTITY PROVIDER ───────────────────────────────────────────────
info "Creating Workload Identity Provider: $PROVIDER_ID ..."
ATTRIBUTE_CONDITION="assertion.repository_owner == '${GITHUB_ORG}'"
[[ -n "$GITHUB_REPO" ]] && ATTRIBUTE_CONDITION="assertion.repository == '${GITHUB_ORG}/${GITHUB_REPO}'"

if gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
  --workload-identity-pool="$POOL_ID" \
  --location="global" \
  --project="$PROJECT_ID" &>/dev/null; then

  warn "Provider '$PROVIDER_ID' already exists — updating attribute condition..."
  gcloud iam workload-identity-pools providers update-oidc "$PROVIDER_ID" \
    --project="$PROJECT_ID" \
    --location="global" \
    --workload-identity-pool="$POOL_ID" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
    --attribute-condition="$ATTRIBUTE_CONDITION" \
    --quiet
else
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
    --project="$PROJECT_ID" \
    --location="global" \
    --workload-identity-pool="$POOL_ID" \
    --display-name="GitHub Actions OIDC" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
    --attribute-condition="$ATTRIBUTE_CONDITION" \
    --quiet
  success "Provider created."
fi

# ─── SERVICE ACCOUNT ──────────────────────────────────────────────────────────
info "Creating service account: $SA_NAME ..."
if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
  warn "Service account '$SA_EMAIL' already exists — skipping creation."
else
  gcloud iam service-accounts create "$SA_NAME" \
    --project="$PROJECT_ID" \
    --display-name="Terraform Deployer (GitHub Actions)" \
    --description="Used by GitHub Actions to run Terraform" \
    --quiet
  success "Service account created."
fi

# ─── IAM ROLES FOR TERRAFORM ──────────────────────────────────────────────────
info "Granting IAM roles to service account..."
TF_ROLES=(
  roles/compute.networkAdmin          # VPC / subnets / firewall
  roles/compute.securityAdmin         # firewall rules
  roles/container.admin               # GKE clusters & node pools
  roles/iam.roleAdmin                 # create/manage custom IAM roles
  roles/iam.serviceAccountAdmin       # create/manage service accounts
  roles/iam.serviceAccountUser        # attach SAs to resources
  roles/resourcemanager.projectIamAdmin  # bind roles at project level
  roles/storage.admin                 # GCS bucket for TF state
  roles/serviceusage.serviceUsageAdmin   # enable APIs via TF
)
for ROLE in "${TF_ROLES[@]}"; do
  if gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$ROLE" \
    --condition=None \
    --quiet; then
    info "  bound $ROLE"
  else
    die "Failed to bind $ROLE to $SA_EMAIL — re-run as a project Owner, then retry."
  fi
done
success "IAM roles granted."

# ─── ALLOW GITHUB ACTIONS TO IMPERSONATE THE SA ───────────────────────────────
info "Binding Workload Identity Pool → Service Account..."

if [[ -n "$GITHUB_REPO" ]]; then
  PRINCIPAL="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${GITHUB_ORG}/${GITHUB_REPO}"
else
  PRINCIPAL="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository_owner/${GITHUB_ORG}"
fi

gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --project="$PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="$PRINCIPAL" \
  --quiet
success "WIF → SA binding created."

# ─── GCS TERRAFORM STATE BUCKET ───────────────────────────────────────────────
info "Setting up Terraform state bucket: gs://${TF_BUCKET} ..."
if gsutil ls -p "$PROJECT_ID" "gs://${TF_BUCKET}" &>/dev/null; then
  warn "Bucket 'gs://${TF_BUCKET}' already exists — skipping creation."
else
  gcloud storage buckets create "gs://${TF_BUCKET}" \
    --project="$PROJECT_ID" \
    --location="$REGION" \
    --uniform-bucket-level-access \
    --public-access-prevention \
    --quiet
  # Enable versioning so TF state history is retained
  gcloud storage buckets update "gs://${TF_BUCKET}" \
    --versioning \
    --quiet
  success "Bucket created with versioning."
fi

# Grant SA objectAdmin on the state bucket (required for terraform init / plan / apply)
if gcloud storage buckets add-iam-policy-binding "gs://${TF_BUCKET}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin" \
  --quiet; then
  success "SA granted objectAdmin on state bucket."
else
  die "Failed to grant objectAdmin on gs://${TF_BUCKET} for ${SA_EMAIL}.
  The Terraform pipeline WILL fail at init without this grant.
  Re-run as a project Owner or Storage Admin, then retry."
fi

# ─── RESOLVE FULL PROVIDER RESOURCE NAME ──────────────────────────────────────
WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup complete. Add these as GitHub Actions secrets/vars:${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${YELLOW}Secret name${NC}                         ${YELLOW}Value${NC}"
echo -e "  ──────────────────────────────────────────────────────────"
echo -e "  GCP_WORKLOAD_IDENTITY_PROVIDER       ${CYAN}${WIF_PROVIDER}${NC}"
echo -e "  GCP_SERVICE_ACCOUNT                  ${CYAN}${SA_EMAIL}${NC}"
echo -e "  TF_STATE_BUCKET                      ${CYAN}${TF_BUCKET}${NC}"
echo ""
echo -e "  Terraform backend bucket: ${CYAN}gs://${TF_BUCKET}${NC}"
echo ""
