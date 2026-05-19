output "rule_allow_internal" {
  description = "Name of the allow-internal firewall rule"
  value       = google_compute_firewall.allow_internal.name
}

output "rule_allow_health_checks" {
  description = "Name of the allow-health-checks firewall rule"
  value       = google_compute_firewall.allow_health_checks.name
}

output "rule_allow_gke_master" {
  description = "Name of the allow-gke-master firewall rule"
  value       = google_compute_firewall.allow_gke_master.name
}

output "rule_allow_asm" {
  description = "Name of the allow-asm firewall rule"
  value       = google_compute_firewall.allow_asm.name
}
