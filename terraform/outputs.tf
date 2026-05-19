output "vpc_network_name" {
  description = "VPC network name"
  value       = module.vpc.network_name
}

output "vpc_network_self_link" {
  description = "VPC network self-link"
  value       = module.vpc.network_self_link
}

output "vpc_subnet_name" {
  description = "Primary subnet name"
  value       = module.vpc.subnet_name
}

output "vpc_subnet_self_link" {
  description = "Primary subnet self-link"
  value       = module.vpc.subnet_self_link
}

output "gke_pods_range_name" {
  description = "Secondary range name to use for GKE pods"
  value       = module.vpc.pods_range_name
}

output "gke_services_range_name" {
  description = "Secondary range name to use for GKE services"
  value       = module.vpc.services_range_name
}
