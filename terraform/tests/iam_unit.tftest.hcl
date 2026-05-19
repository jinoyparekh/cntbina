# Unit tests for the iam module.
# Run: terraform test -filter=tests/iam_unit.tftest.hcl

mock_provider "google" {}

variables {
  project_id  = "mock-project"
  region      = "us-central1"
  environment = "lab"
}

run "gke_node_sa_email_follows_naming_convention" {
  command = plan

  assert {
    condition     = module.iam.gke_node_sa_email == "lab-cntbina-gke-node@mock-project.iam.gserviceaccount.com"
    error_message = "GKE node SA email must be '<name>-gke-node@<project>.iam.gserviceaccount.com'"
  }
}

run "security_tools_sa_email_follows_naming_convention" {
  command = plan

  assert {
    condition     = module.iam.security_tools_sa_email == "lab-cntbina-sec-tools@mock-project.iam.gserviceaccount.com"
    error_message = "Security tools SA email must be '<name>-sec-tools@<project>.iam.gserviceaccount.com'"
  }
}

run "sa_emails_are_distinct" {
  command = plan

  assert {
    condition     = module.iam.gke_node_sa_email != module.iam.security_tools_sa_email
    error_message = "GKE node SA and security tools SA must be different service accounts"
  }
}
