# Unit tests for the subnets module.
# Run: terraform test -filter=tests/subnets_unit.tftest.hcl

mock_provider "google" {}

variables {
  project_id  = "mock-project"
  region      = "us-central1"
  environment = "lab"
}

run "subnet_name_includes_nodes_and_region" {
  command = plan

  assert {
    condition     = module.subnets.subnet_name == "lab-cntbina-nodes-us-central1"
    error_message = "Subnet name must be '<name>-nodes-<region>', got: ${module.subnets.subnet_name}"
  }
}

run "gke_secondary_range_names_are_correct" {
  command = plan

  assert {
    condition     = module.subnets.pods_range_name == "pods"
    error_message = "pods secondary range must be named 'pods'"
  }

  assert {
    condition     = module.subnets.services_range_name == "services"
    error_message = "services secondary range must be named 'services'"
  }
}

run "default_cidrs_are_right_sized" {
  command = plan

  assert {
    condition     = module.subnets.nodes_cidr == "10.0.0.0/24"
    error_message = "default nodes CIDR must be 10.0.0.0/24"
  }

  assert {
    condition     = module.subnets.pods_cidr == "10.1.0.0/21"
    error_message = "default pods CIDR must be 10.1.0.0/21"
  }

  assert {
    condition     = module.subnets.services_cidr == "10.2.0.0/24"
    error_message = "default services CIDR must be 10.2.0.0/24"
  }
}

run "invalid_flow_log_sampling_rejected" {
  command = plan

  variables {
    flow_log_sampling = 0.05
  }

  expect_failures = [var.flow_log_sampling]
}
