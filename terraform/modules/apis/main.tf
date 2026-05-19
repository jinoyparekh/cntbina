locals {
  # Required APIs grouped by what they unlock.
  # disable_on_destroy = false: never disable an API on terraform destroy —
  # other workloads in the project may depend on it.
  required_apis = toset([
    # ── Compute / Networking ───────────────────────────────────────────────
    "compute.googleapis.com",              # VPC, subnets, firewall, NAT, GKE nodes

    # ── GKE ───────────────────────────────────────────────────────────────
    "container.googleapis.com",            # GKE cluster + node pools

    # ── Anthos Service Mesh ───────────────────────────────────────────────
    "mesh.googleapis.com",                 # Managed ASM control plane
    "anthos.googleapis.com",               # Anthos platform (ASM pre-req)
    "gkehub.googleapis.com",               # Fleet/Hub membership (ASM registration)
    "meshca.googleapis.com",               # Mesh Certificate Authority (mTLS)

    # ── Binary Authorization ──────────────────────────────────────────────
    "binaryauthorization.googleapis.com",  # image admission policy
    "containeranalysis.googleapis.com",    # vulnerability notes + attestations
    "containersecurity.googleapis.com",    # container threat detection

    # ── IAM / Identity ────────────────────────────────────────────────────
    "iam.googleapis.com",                  # service accounts, roles
    "iamcredentials.googleapis.com",       # workload identity token exchange
    "cloudresourcemanager.googleapis.com", # project IAM policy management

    # ── Images ────────────────────────────────────────────────────────────
    "artifactregistry.googleapis.com",     # private container registry

    # ── Observability (required by GKE + ASM) ────────────────────────────
    "dns.googleapis.com",                  # DNS policy + query logging
    "logging.googleapis.com",              # Cloud Logging
    "monitoring.googleapis.com",           # Cloud Monitoring
    "stackdriver.googleapis.com",          # metadata writer (node agent)

    # ── CSPM / CWPP tools (Wiz, Prisma, AccuKnox) ────────────────────────
    "cloudasset.googleapis.com",           # cloud asset inventory API
  ])

  all_apis = toset(concat(tolist(local.required_apis), var.extra_apis))
}

resource "google_project_service" "required" {
  for_each = local.all_apis

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
