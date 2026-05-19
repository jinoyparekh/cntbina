resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = var.name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# DNS query logging — critical for threat detection in a security lab
resource "google_dns_policy" "logging" {
  project        = var.project_id
  name           = "${var.name}-dns-logging"
  enable_logging = true

  networks {
    network_url = google_compute_network.this.id
  }
}

resource "google_compute_router" "this" {
  project = var.project_id
  name    = "${var.name}-router"
  network = google_compute_network.this.id
  region  = var.region
}

# NAT so private nodes can reach internet (image pulls, vendor agents) without public IPs
resource "google_compute_router_nat" "this" {
  project                            = var.project_id
  name                               = "${var.name}-nat"
  router                             = google_compute_router.this.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
