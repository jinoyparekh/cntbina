variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "name" {
  description = "Base name for subnet resources"
  type        = string
}

variable "network_id" {
  description = "VPC network resource ID"
  type        = string
}

# Right-sized for a security test lab (~10 nodes, 110 pods/node):
# nodes:    /24 → 254 IPs  (10 nodes with headroom)
# pods:     /21 → 2046 IPs (~18 nodes × 110 pods)
# services: /24 → 254 IPs  (plenty for test lab services)
# master:   /28 → required by GKE (output only, not a subnet resource)

variable "nodes_cidr" {
  description = "Primary CIDR for GKE node VMs"
  type        = string
  default     = "10.0.0.0/24"
}

variable "pods_cidr" {
  description = "Secondary range CIDR for GKE pods"
  type        = string
  default     = "10.1.0.0/21"
}

variable "services_cidr" {
  description = "Secondary range CIDR for GKE services"
  type        = string
  default     = "10.2.0.0/24"
}

variable "flow_log_sampling" {
  description = "VPC flow log sampling rate (0.1–1.0). Higher = more telemetry, more cost."
  type        = number
  default     = 0.5

  validation {
    condition     = var.flow_log_sampling >= 0.1 && var.flow_log_sampling <= 1.0
    error_message = "flow_log_sampling must be between 0.1 and 1.0."
  }
}
