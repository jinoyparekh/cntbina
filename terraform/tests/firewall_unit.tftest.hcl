# Unit tests for the firewall module.
# Run: terraform test -filter=tests/firewall_unit.tftest.hcl

mock_provider "google" {}

variables {
  project_id  = "mock-project"
  region      = "us-central1"
  environment = "lab"
}

run "firewall_rules_are_created" {
  command = plan

  # Verify the three key rule self-links are non-empty (rules exist in the plan)
  assert {
    condition     = module.firewall.rule_allow_internal != ""
    error_message = "allow-internal firewall rule must be planned"
  }

  assert {
    condition     = module.firewall.rule_allow_gke_master != ""
    error_message = "allow-gke-master firewall rule must be planned"
  }

  assert {
    condition     = module.firewall.rule_allow_asm != ""
    error_message = "allow-asm firewall rule must be planned"
  }
}

run "invalid_master_cidr_prefix_rejected" {
  command = plan

  variables {
    master_cidr = "10.3.0.0/24"  # /24 is invalid — GKE requires /28
  }

  expect_failures = [var.master_cidr]
}
