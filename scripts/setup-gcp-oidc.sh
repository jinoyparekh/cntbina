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
  success "Provider updated."
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
# Requires the caller to have roles/owner or roles/resourcemanager.projectIamAdmin.
info "Granting IAM roles to service account..."
TF_ROLES=(
  roles/compute.networkAdmin             # VPC / subnets / firewall
  roles/compute.securityAdmin            # firewall rules
  roles/container.admin                  # GKE clusters & node pools
  roles/iam.roleAdmin                    # create/manage custom IAM roles
  roles/iam.serviceAccountAdmin          # create/manage service accounts
  roles/iam.serviceAccountUser           # attach SAs to resources
  roles/resourcemanager.projectIamAdmin  # bind roles at project level
  roles/storage.admin                    # GCS bucket for TF state
  roles/serviceusage.serviceUsageAdmin   # enable APIs via TF
)
IAM_FAILED=()
for ROLE in "${TF_ROLES[@]}"; do
  if gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$ROLE" \
    --condition=None \
    --quiet; then
    info "  bound $ROLE"
  else
    warn "  failed to bind $ROLE — skipping (caller lacks resourcemanager.projectIamAdmin?)"
    IAM_FAILED+=("$ROLE")
  fi
done
if [[ ${#IAM_FAILED[@]} -eq 0 ]]; then
  success "All IAM roles granted."
else
  warn "${#IAM_FAILED[@]} role binding(s) failed — see manual steps in the summary below."
fi

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
if gcloud storage ls --buckets "gs://${TF_BUCKET}" --project="$PROJECT_ID" &>/dev/null; then
  warn "Bucket 'gs://${TF_BUCKET}' already exists — skipping creation."
else
  gcloud storage buckets create "gs://${TF_BUCKET}" \
    --project="$PROJECT_ID" \
    --location="$REGION" \
    --uniform-bucket-level-access \
    --public-access-prevention \
    --quiet
  gcloud storage buckets update "gs://${TF_BUCKET}" \
    --versioning \
    --quiet
  success "Bucket created with versioning."
fi

# Grant the deployer SA objectAdmin on the state bucket.
# Requires the caller to have roles/storage.admin on the bucket or project.
BUCKET_IAM_OK=false
if gcloud storage buckets add-iam-policy-binding "gs://${TF_BUCKET}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin" \
  --quiet; then
  success "SA granted objectAdmin on state bucket."
  BUCKET_IAM_OK=true
else
  warn "Could not grant objectAdmin on gs://${TF_BUCKET}."
  warn "The Terraform pipeline WILL fail at init without this grant."
  warn "Re-run as a project Owner / Storage Admin to apply it."
fi

# ─── RESOLVE FULL PROVIDER RESOURCE NAME ──────────────────────────────────────
WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup complete. Add these as GitHub Actions variables:    ${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${YELLOW}Variable name${NC}                        ${YELLOW}Value${NC}"
echo -e "  ──────────────────────────────────────────────────────────"
echo -e "  GCP_PROJECT_ID                       ${CYAN}${PROJECT_ID}${NC}"
echo -e "  GCP_WORKLOAD_IDENTITY_PROVIDER       ${CYAN}${WIF_PROVIDER}${NC}"
echo -e "  GCP_SERVICE_ACCOUNT                  ${CYAN}${SA_EMAIL}${NC}"
echo -e "  TF_STATE_BUCKET                      ${CYAN}${TF_BUCKET}${NC}"
echo ""
echo -e "  Terraform backend bucket: ${CYAN}gs://${TF_BUCKET}${NC}"
echo ""

# ─── MANUAL STEPS REQUIRED (if any grants failed) ─────────────────────────────
NEEDS_MANUAL=false
if [[ ${#IAM_FAILED[@]} -gt 0 ]]; then
  NEEDS_MANUAL=true
  echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
  echo -e "${RED}  ACTION REQUIRED — IAM role bindings that failed:         ${NC}"
  echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "  Run the following as a project Owner:"
  echo ""
  for ROLE in "${IAM_FAILED[@]}"; do
    echo "  gcloud projects add-iam-policy-binding ${PROJECT_ID} \\"
    echo "    --member=\"serviceAccount:${SA_EMAIL}\" \\"
    echo "    --role=\"${ROLE}\" --condition=None"
    echo ""
  done
fi

if [[ "$BUCKET_IAM_OK" == "false" ]]; then
  NEEDS_MANUAL=true
  echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
  echo -e "${RED}  ACTION REQUIRED — state bucket IAM grant failed:         ${NC}"
  echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "  Run the following as a project Owner or Storage Admin:"
  echo ""
  echo "  gcloud storage buckets add-iam-policy-binding gs://${TF_BUCKET} \\"
  echo "    --member=\"serviceAccount:${SA_EMAIL}\" \\"
  echo "    --role=\"roles/storage.objectAdmin\""
  echo ""
fi

if [[ "$NEEDS_MANUAL" == "false" ]]; then
  echo -e "${GREEN}  All grants applied — no manual steps required.${NC}"
  echo ""
fi
