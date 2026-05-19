output "gke_node_sa_email" {
  description = "Email of the GKE node SA — use as node_config.service_account in the GKE module"
  value       = google_service_account.gke_node.email
}

output "gke_node_sa_account_id" {
  description = "account_id of the GKE node SA — known at plan time, use in tests"
  value       = google_service_account.gke_node.account_id
}

output "security_tools_sa_email" {
  description = "Email of the security tools SA — annotate k8s SA with iam.gke.io/gcp-service-account"
  value       = google_service_account.security_tools.email
}

output "security_tools_sa_account_id" {
  description = "account_id of the security tools SA — known at plan time, use in tests"
  value       = google_service_account.security_tools.account_id
}
