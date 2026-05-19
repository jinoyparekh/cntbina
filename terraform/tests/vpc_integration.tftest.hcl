# Integration tests — full stack plan + apply against real GCP.
# Requires: GOOGLE_PROJECT env var or TF_VAR_project_id + valid credentials.
# Run: terraform test -filter=tests/vpc_integration.tftest.hcl
#
# Uses isolated CIDRs to avoid overlapping existing networks in the project.

variables {
  project_id        = "replace-with-project-id"
  region            = "us-central1"
  environment       = "test"
  nodes_cidr        = "10.100.0.0/24"
  pods_cidr         = "10.101.0.0/21"
  services_cidr     = "10.102.0.0/24"
  master_cidr       = "10.103.0.0/28"
  flow_log_sampling = 0.1
}

run "full_stack_plan_succeeds" {
  command = plan

  assert {
    condition     = module.vpc.network_name == "test-cntbina"
    error_message = "VPC name mismatch"
  }

  assert {
    condition     = module.subnets.subnet_name == "test-cntbina-nodes-us-central1"
    error_message = "Subnet name mismatch"
  }

  assert {
    condition     = module.subnets.nodes_cidr == "10.100.0.0/24"
    error_message = "Nodes CIDR mismatch"
  }

  assert {
    condition     = module.iam.gke_node_sa_email == "test-cntbina-gke-node@replace-with-project-id.iam.gserviceaccount.com"
    error_message = "GKE node SA email mismatch"
  }
}

run "full_stack_apply" {
  command = apply

  assert {
    condition     = module.vpc.network_name == "test-cntbina"
    error_message = "VPC name mismatch after apply"
  }

  assert {
    condition     = module.subnets.pods_range_name == "pods"
    error_message = "Pods range name missing after apply"
  }

  assert {
    condition     = module.subnets.services_range_name == "services"
    error_message = "Services range name missing after apply"
  }

  assert {
    condition     = output.gke_node_tag == "test-cntbina-gke-node"
    error_message = "GKE node tag mismatch after apply"
  }
}
