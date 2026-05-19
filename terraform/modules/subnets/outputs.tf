output "subnet_name" {
  value = google_compute_subnetwork.nodes.name
}

output "subnet_self_link" {
  value = google_compute_subnetwork.nodes.self_link
}

output "nodes_cidr" {
  value = google_compute_subnetwork.nodes.ip_cidr_range
}

output "pods_cidr" {
  value = google_compute_subnetwork.nodes.secondary_ip_range[0].ip_cidr_range
}

output "services_cidr" {
  value = google_compute_subnetwork.nodes.secondary_ip_range[1].ip_cidr_range
}

output "pods_range_name" {
  value = "pods"
}

output "services_range_name" {
  value = "services"
}
