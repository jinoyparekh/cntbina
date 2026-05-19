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
  description = "Environment label: dev, staging, or prod"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "vpc_subnet_cidr" {
  description = "Primary subnet CIDR"
  type        = string
  default     = "10.10.0.0/20"
}

variable "vpc_pods_cidr" {
  description = "Secondary range CIDR for GKE pods"
  type        = string
  default     = "10.20.0.0/16"
}

variable "vpc_services_cidr" {
  description = "Secondary range CIDR for GKE services"
  type        = string
  default     = "10.30.0.0/20"
}
