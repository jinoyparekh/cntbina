# ── VPC ────────────────────────────────────────────────────────────────────────
output "vpc_name" {
  description = "VPC network name"
  value       = module.vpc.network_name
}

output "vpc_self_link" {
  description = "VPC network self-link"
  value       = module.vpc.network_self_link
}

# ── Subnets ────────────────────────────────────────────────────────────────────
output "subnet_name" {
  description = "Node subnet name"
  value       = module.subnets.subnet_name
}

output "subnet_self_link" {
  description = "Node subnet self-link"
  value       = module.subnets.subnet_self_link
}

output "pods_range_name" {
  description = "Secondary range name for GKE pods — pass to cluster.ip_allocation_policy"
  value       = module.subnets.pods_range_name
}

output "services_range_name" {
  description = "Secondary range name for GKE services — pass to cluster.ip_allocation_policy"
  value       = module.subnets.services_range_name
}

# ── GKE inputs (consumed by GKE module when added) ────────────────────────────
output "gke_node_tag" {
  description = "Network tag to set on GKE node pools — must match firewall target_tags"
  value       = local.node_tag
}

output "master_cidr" {
  description = "GKE control plane CIDR — pass to private_cluster_config.master_ipv4_cidr_block"
  value       = var.master_cidr
}

# ── IAM ────────────────────────────────────────────────────────────────────────
output "gke_node_sa_email" {
  description = "GKE node SA email — pass to node_config.service_account"
  value       = module.iam.gke_node_sa_email
}

output "security_tools_sa_email" {
  description = "Security tools SA email — annotate k8s SA with iam.gke.io/gcp-service-account"
  value       = module.iam.security_tools_sa_email
}
