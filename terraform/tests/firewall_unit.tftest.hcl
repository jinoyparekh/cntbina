# Unit tests for the firewall module.
# Asserts on resource *names* (input-derived, known at plan time).
# self_link is GCP-computed and always empty with mock_provider — do not assert on it.
# Run: terraform test -filter=tests/firewall_unit.tftest.hcl

mock_provider "google" {}

variables {
  project_id  = "mock-project"
  region      = "us-central1"
  environment = "lab"
}

run "firewall_rule_names_follow_naming_convention" {
  command = plan

  assert {
    condition     = module.firewall.rule_allow_internal == "lab-cntbina-allow-internal"
    error_message = "allow-internal rule must be named '<name>-allow-internal'"
  }

  assert {
    condition     = module.firewall.rule_allow_gke_master == "lab-cntbina-allow-gke-master"
    error_message = "allow-gke-master rule must be named '<name>-allow-gke-master'"
  }

  assert {
    condition     = module.firewall.rule_allow_asm == "lab-cntbina-allow-asm"
    error_message = "allow-asm rule must be named '<name>-allow-asm'"
  }

  assert {
    condition     = module.firewall.rule_allow_health_checks == "lab-cntbina-allow-health-checks"
    error_message = "allow-health-checks rule must be named '<name>-allow-health-checks'"
  }
}

run "invalid_master_cidr_prefix_rejected" {
  command = plan

  variables {
    master_cidr = "10.3.0.0/24"   # /24 is invalid — GKE requires /28
  }

  # override_module prevents the firewall module's own /28 validation from firing
  # as an unexpected second failure. The root var.master_cidr validation is the
  # authoritative rejection point and the only one expect_failures can reference.
  override_module {
    target = module.firewall
    outputs = {
      rule_allow_internal      = "mock"
      rule_allow_gke_master    = "mock"
      rule_allow_asm           = "mock"
      rule_allow_health_checks = "mock"
    }
  }

  expect_failures = [var.master_cidr]
}
