# ── GKE Node Service Account ──────────────────────────────────────────────────
# Replaces the default Compute Engine SA. Least-privilege: only what kubelet needs.
resource "google_service_account" "gke_node" {
  project      = var.project_id
  account_id   = "${var.name}-gke-node"
  display_name = "GKE Node — ${var.name}"
  description  = "Attached to GKE node pools. Scoped to kubelet + observability only."
}

locals {
  gke_node_roles = [
    "roles/logging.logWriter",                    # write node/container logs to Cloud Logging
    "roles/monitoring.metricWriter",              # write metrics to Cloud Monitoring
    "roles/monitoring.viewer",                    # read monitoring data (required by some node agents)
    "roles/stackdriver.resourceMetadata.writer",  # metadata for k8s resource model
    "roles/artifactregistry.reader",              # pull images from Artifact Registry
  ]
}

resource "google_project_iam_member" "gke_node" {
  for_each = toset(local.gke_node_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.gke_node.email}"
}

# ── Security Tools Workload Identity SA ───────────────────────────────────────
# Used by CSPM/CWPP pods (Wiz, AccuKnox, Prisma, BinAuthZ) via Workload Identity.
# Read-heavy: scans GCP resources without write access.
resource "google_service_account" "security_tools" {
  project      = var.project_id
  account_id   = "${var.name}-sec-tools"
  display_name = "Security Tools WI — ${var.name}"
  description  = "CSPM/CWPP pods access GCP APIs via this SA through Workload Identity."
}

locals {
  security_tools_roles = [
    "roles/viewer",                           # read all GCP resource metadata
    "roles/iam.securityReviewer",             # inspect IAM policies (needed by Wiz/Prisma)
    "roles/cloudasset.viewer",                # cloud asset inventory API (CSPM posture)
    "roles/binaryauthorization.policyAdmin",  # BinAuthZ policy read/write for lab testing
    "roles/containeranalysis.notes.viewer",   # vulnerability notes for attestation workflows
  ]
}

resource "google_project_iam_member" "security_tools" {
  for_each = toset(local.security_tools_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.security_tools.email}"
}

# Bind k8s ServiceAccount → GCP SA via Workload Identity
# The k8s SA named "security-tools" in the configured namespace can impersonate this GCP SA
resource "google_service_account_iam_member" "security_tools_wi" {
  service_account_id = google_service_account.security_tools.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/security-tools]"
}
