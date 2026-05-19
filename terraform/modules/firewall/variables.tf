variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "name" {
  description = "Base name for firewall rules"
  type        = string
}

variable "network_id" {
  description = "VPC network resource ID"
  type        = string
}

variable "nodes_cidr" {
  description = "Node subnet CIDR"
  type        = string
}

variable "pods_cidr" {
  description = "Pod secondary range CIDR"
  type        = string
}

variable "services_cidr" {
  description = "Services secondary range CIDR"
  type        = string
}

variable "master_cidr" {
  description = "GKE control plane CIDR. Must be /28 (GKE requirement)."
  type        = string
  default     = "10.3.0.0/28"

  validation {
    condition     = can(cidrhost(var.master_cidr, 0)) && split("/", var.master_cidr)[1] == "28"
    error_message = "master_cidr must be a valid /28 CIDR block (GKE requirement)."
  }
}

variable "node_tag" {
  description = "Network tag applied to GKE node VMs. Must match node pool tags."
  type        = string
}
