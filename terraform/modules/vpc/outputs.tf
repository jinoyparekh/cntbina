output "network_id" {
  description = "VPC network resource ID"
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.this.name
}

output "network_self_link" {
  description = "VPC network self-link (used by GKE, GCE, etc.)"
  value       = google_compute_network.this.self_link
}

output "subnet_name" {
  description = "Primary subnet name"
  value       = google_compute_subnetwork.this.name
}

output "subnet_self_link" {
  description = "Primary subnet self-link"
  value       = google_compute_subnetwork.this.self_link
}

output "pods_range_name" {
  description = "Secondary range name for GKE pods"
  value       = "pods"
}

output "services_range_name" {
  description = "Secondary range name for GKE services"
  value       = "services"
}
