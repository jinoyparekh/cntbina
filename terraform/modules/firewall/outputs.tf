output "rule_allow_internal" {
  description = "Self-link of the allow-internal firewall rule"
  value       = google_compute_firewall.allow_internal.self_link
}

output "rule_allow_gke_master" {
  description = "Self-link of the allow-gke-master firewall rule"
  value       = google_compute_firewall.allow_gke_master.self_link
}

output "rule_allow_asm" {
  description = "Self-link of the allow-asm firewall rule"
  value       = google_compute_firewall.allow_asm.self_link
}
