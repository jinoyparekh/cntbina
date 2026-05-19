output "gke_node_sa_email" {
  description = "Email of the GKE node service account — use as node_config.service_account in the GKE module"
  value       = google_service_account.gke_node.email
}

output "gke_node_sa_name" {
  description = "Full resource name of the GKE node SA"
  value       = google_service_account.gke_node.name
}

output "security_tools_sa_email" {
  description = "Email of the security tools SA — annotate k8s SA with this for Workload Identity"
  value       = google_service_account.security_tools.email
}

output "security_tools_sa_name" {
  description = "Full resource name of the security tools SA"
  value       = google_service_account.security_tools.name
}
