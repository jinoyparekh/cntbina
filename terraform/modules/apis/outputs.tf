output "enabled_apis" {
  description = "Set of API service names that were enabled. Use for assertions in tests."
  value       = toset(keys(google_project_service.required))
}
