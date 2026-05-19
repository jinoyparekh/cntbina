variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Primary GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment: lab, dev, staging, or prod"
  type        = string
  default     = "lab"

  validation {
    condition     = contains(["lab", "dev", "staging", "prod"], var.environment)
    error_message = "environment must be lab, dev, staging, or prod."
  }
}

# ── CIDRs ─────────────────────────────────────────────────────────────────────
# Right-sized for a security test lab (~10 nodes, 110 pods/node).
# All ranges fit cleanly within 10.0.0.0/20.
#
#   nodes:    10.0.0.0/24  → 254 IPs   (10 nodes with headroom)
#   pods:     10.1.0.0/21  → 2046 IPs  (~18 nodes × 110 pods)
#   services: 10.2.0.0/24  → 254 IPs
#   master:   10.3.0.0/28  → /28 required by GKE

variable "nodes_cidr" {
  description = "Primary CIDR for GKE node VMs"
  type        = string
  default     = "10.0.0.0/24"
}

variable "pods_cidr" {
  description = "Secondary range for GKE pods"
  type        = string
  default     = "10.1.0.0/21"
}

variable "services_cidr" {
  description = "Secondary range for GKE services"
  type        = string
  default     = "10.2.0.0/24"
}

variable "master_cidr" {
  description = "GKE control plane CIDR. Must be /28 and must not overlap any subnet."
  type        = string
  default     = "10.3.0.0/28"
}

variable "flow_log_sampling" {
  description = "Subnet flow log sampling rate (0.1–1.0)"
  type        = number
  default     = 0.5

  validation {
    condition     = var.flow_log_sampling >= 0.1 && var.flow_log_sampling <= 1.0
    error_message = "flow_log_sampling must be between 0.1 and 1.0."
  }
}

# ── Workload Identity ──────────────────────────────────────────────────────────
variable "k8s_namespace" {
  description = "Kubernetes namespace where security tool pods run (for Workload Identity binding)"
  type        = string
  default     = "security-tools"
}

variable "extra_apis" {
  description = "Additional GCP APIs to enable beyond the required set (e.g. secretmanager.googleapis.com)"
  type        = list(string)
  default     = []
}
