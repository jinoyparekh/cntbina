output "network_id" {
  description = "VPC network resource ID"
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.this.name
}

output "network_self_link" {
  description = "VPC network self-link (used by GKE, subnetworks, firewall)"
  value       = google_compute_network.this.self_link
}
