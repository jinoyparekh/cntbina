variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "extra_apis" {
  description = "Additional APIs to enable on top of the required set (e.g. for future modules)"
  type        = list(string)
  default     = []
}
