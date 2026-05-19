locals {
  internal_ranges = [var.nodes_cidr, var.pods_cidr, var.services_cidr]
}

# All TCP/UDP/ICMP/SCTP within VPC ranges (nodes ↔ pods ↔ services)
# SCTP included because ASM/Envoy uses it for some internal paths
resource "google_compute_firewall" "allow_internal" {
  project   = var.project_id
  name      = "${var.name}-allow-internal"
  network   = var.network_id
  direction = "INGRESS"
  priority  = 1000

  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }
  allow { protocol = "sctp" }

  source_ranges = local.internal_ranges
  target_tags   = [var.node_tag]
}

# GCP health check probes — required for load balancers and GKE node health
resource "google_compute_firewall" "allow_health_checks" {
  project   = var.project_id
  name      = "${var.name}-allow-health-checks"
  network   = var.network_id
  direction = "INGRESS"
  priority  = 1000

  allow { protocol = "tcp" }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = [var.node_tag]
}

# GKE control plane → nodes
# 443:   kube-apiserver
# 10250: kubelet API
# 15017: ASM/Istio sidecar injection webhook (istiod MutatingWebhookConfiguration)
resource "google_compute_firewall" "allow_gke_master" {
  project   = var.project_id
  name      = "${var.name}-allow-gke-master"
  network   = var.network_id
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["443", "10250", "15017"]
  }

  source_ranges = [var.master_cidr]
  target_tags   = [var.node_tag]
}

# ASM / Anthos Service Mesh sidecar ↔ istiod communication
# 15012: istiod gRPC-TLS (XDS config, certificate distribution)
# 15014: istiod control-plane metrics (Prometheus scrape)
# 15021: Envoy sidecar health check endpoint
# 15090: Envoy Prometheus metrics endpoint
resource "google_compute_firewall" "allow_asm" {
  project   = var.project_id
  name      = "${var.name}-allow-asm"
  network   = var.network_id
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["15012", "15014", "15021", "15090"]
  }

  source_ranges = local.internal_ranges
  target_tags   = [var.node_tag]
}
