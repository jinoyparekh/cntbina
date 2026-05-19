# Integration tests — runs a real plan/apply against GCP.
# Requires: GOOGLE_PROJECT env var or TF_VAR_project_id set + valid credentials.
# Run: terraform test -filter=tests/vpc_integration.tftest.hcl

variables {
  project_id  = env("GOOGLE_PROJECT") != "" ? env("GOOGLE_PROJECT") : "replace-with-project-id"
  region      = "us-central1"
  environment = "test"

  # Unique CIDRs to avoid conflicts with existing networks in the project
  vpc_subnet_cidr   = "10.110.0.0/20"
  vpc_pods_cidr     = "10.120.0.0/16"
  vpc_services_cidr = "10.130.0.0/20"
}

run "plan_succeeds" {
  command = plan

  assert {
    condition     = module.vpc.network_name == "test-vpc"
    error_message = "Expected network name 'test-vpc'"
  }
}

run "apply_and_verify" {
  command = apply

  assert {
    condition     = module.vpc.network_name == "test-vpc"
    error_message = "Network name mismatch after apply"
  }

  assert {
    condition     = module.vpc.subnet_name == "test-vpc-subnet-us-central1"
    error_message = "Subnet name mismatch after apply"
  }

  assert {
    condition     = module.vpc.pods_range_name == "pods"
    error_message = "Pods range name missing"
  }

  assert {
    condition     = module.vpc.services_range_name == "services"
    error_message = "Services range name missing"
  }
}
