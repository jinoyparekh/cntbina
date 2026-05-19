# Unit tests for the vpc module.
# Uses mock_provider — no GCP credentials required.
# Run: terraform test -filter=tests/vpc_unit.tftest.hcl

mock_provider "google" {}

variables {
  project_id  = "mock-project"
  region      = "us-central1"
  environment = "lab"
}

run "vpc_name_is_environment_prefixed" {
  command = plan

  assert {
    condition     = module.vpc.network_name == "lab-cntbina"
    error_message = "VPC name must be '<environment>-cntbina', got: ${module.vpc.network_name}"
  }
}

run "invalid_environment_rejected" {
  command = plan

  variables {
    environment = "production"
  }

  expect_failures = [var.environment]
}
