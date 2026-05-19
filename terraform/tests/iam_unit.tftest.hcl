# Unit tests for the iam module.
# Asserts on account_id (input-derived, known at plan time).
# email/name are GCP-computed and always empty with mock_provider — do not assert on them.
# Run: terraform test -filter=tests/iam_unit.tftest.hcl

mock_provider "google" {}

variables {
  project_id  = "mock-project"
  region      = "us-central1"
  environment = "lab"
}

run "gke_node_sa_account_id_follows_naming_convention" {
  command = plan

  assert {
    condition     = module.iam.gke_node_sa_account_id == "lab-cntbina-gke-node"
    error_message = "GKE node SA account_id must be '<name>-gke-node', got: ${module.iam.gke_node_sa_account_id}"
  }
}

run "security_tools_sa_account_id_follows_naming_convention" {
  command = plan

  assert {
    condition     = module.iam.security_tools_sa_account_id == "lab-cntbina-sec-tools"
    error_message = "Security tools SA account_id must be '<name>-sec-tools', got: ${module.iam.security_tools_sa_account_id}"
  }
}

run "sa_account_ids_are_distinct" {
  command = plan

  assert {
    condition     = module.iam.gke_node_sa_account_id != module.iam.security_tools_sa_account_id
    error_message = "GKE node SA and security tools SA must have different account IDs"
  }
}
