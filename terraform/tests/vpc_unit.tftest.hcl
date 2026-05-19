# Unit tests — mock provider, no GCP credentials required.
# Run: terraform test -filter=tests/vpc_unit.tftest.hcl

mock_provider "google" {}

variables {
  project_id  = "mock-project"
  region      = "us-central1"
  environment = "dev"
}

run "vpc_name_follows_environment_prefix" {
  command = plan

  assert {
    condition     = module.vpc.network_name == "dev-vpc"
    error_message = "VPC name must be '<environment>-vpc', got: ${module.vpc.network_name}"
  }
}

run "subnet_name_includes_region" {
  command = plan

  assert {
    condition     = module.vpc.subnet_name == "dev-vpc-subnet-us-central1"
    error_message = "Subnet name must follow '<vpc-name>-subnet-<region>' pattern"
  }
}

run "gke_secondary_ranges_are_exposed" {
  command = plan

  assert {
    condition     = module.vpc.pods_range_name == "pods"
    error_message = "pods range name must be 'pods'"
  }

  assert {
    condition     = module.vpc.services_range_name == "services"
    error_message = "services range name must be 'services'"
  }
}

run "invalid_environment_is_rejected" {
  command = plan

  variables {
    environment = "production"
  }

  expect_failures = [var.environment]
}
