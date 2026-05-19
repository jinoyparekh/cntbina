locals {
  name     = "${var.environment}-cntbina"
  node_tag = "${local.name}-gke-node"
}

# ── APIs ───────────────────────────────────────────────────────────────────────
# All other modules depend on this. APIs can take 60-90s to activate after enable.
module "apis" {
  source = "./modules/apis"

  project_id = var.project_id
  extra_apis = var.extra_apis
}

# ── VPC ────────────────────────────────────────────────────────────────────────
module "vpc" {
  source     = "./modules/vpc"
  depends_on = [module.apis]

  project_id = var.project_id
  region     = var.region
  name       = local.name
}

# ── Subnets ────────────────────────────────────────────────────────────────────
module "subnets" {
  source     = "./modules/subnets"
  depends_on = [module.vpc]

  project_id        = var.project_id
  region            = var.region
  name              = local.name
  network_id        = module.vpc.network_id
  nodes_cidr        = var.nodes_cidr
  pods_cidr         = var.pods_cidr
  services_cidr     = var.services_cidr
  flow_log_sampling = var.flow_log_sampling
}

# ── Firewall ───────────────────────────────────────────────────────────────────
module "firewall" {
  source     = "./modules/firewall"
  depends_on = [module.vpc]

  project_id    = var.project_id
  name          = local.name
  network_id    = module.vpc.network_id
  nodes_cidr    = module.subnets.nodes_cidr
  pods_cidr     = module.subnets.pods_cidr
  services_cidr = module.subnets.services_cidr
  master_cidr   = var.master_cidr
  node_tag      = local.node_tag
}

# ── IAM ────────────────────────────────────────────────────────────────────────
module "iam" {
  source     = "./modules/iam"
  depends_on = [module.apis]

  project_id    = var.project_id
  name          = local.name
  k8s_namespace = var.k8s_namespace
}
