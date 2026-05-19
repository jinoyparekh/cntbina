variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "name" {
  description = "Base name prefix for service accounts (max ~20 chars to stay under 30-char SA limit)"
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for Workload Identity binding of the security-tools SA"
  type        = string
  default     = "security-tools"
}
