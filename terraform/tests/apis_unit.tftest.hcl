# Unit tests for the apis module.
# Run: terraform test -filter=tests/apis_unit.tftest.hcl

mock_provider "google" {}

variables {
  project_id  = "mock-project"
  region      = "us-central1"
  environment = "lab"
}

run "gke_api_is_enabled" {
  command = plan

  assert {
    condition     = contains(module.apis.enabled_apis, "container.googleapis.com")
    error_message = "container.googleapis.com must be enabled — required for GKE"
  }
}

run "asm_apis_are_enabled" {
  command = plan

  assert {
    condition     = contains(module.apis.enabled_apis, "mesh.googleapis.com")
    error_message = "mesh.googleapis.com must be enabled — required for ASM"
  }

  assert {
    condition     = contains(module.apis.enabled_apis, "gkehub.googleapis.com")
    error_message = "gkehub.googleapis.com must be enabled — required for ASM fleet registration"
  }

  assert {
    condition     = contains(module.apis.enabled_apis, "meshca.googleapis.com")
    error_message = "meshca.googleapis.com must be enabled — required for ASM mTLS"
  }
}

run "binauthz_apis_are_enabled" {
  command = plan

  assert {
    condition     = contains(module.apis.enabled_apis, "binaryauthorization.googleapis.com")
    error_message = "binaryauthorization.googleapis.com must be enabled"
  }

  assert {
    condition     = contains(module.apis.enabled_apis, "containeranalysis.googleapis.com")
    error_message = "containeranalysis.googleapis.com must be enabled — required for BinAuthZ attestations"
  }
}

run "cspm_apis_are_enabled" {
  command = plan

  assert {
    condition     = contains(module.apis.enabled_apis, "cloudasset.googleapis.com")
    error_message = "cloudasset.googleapis.com must be enabled — required for CSPM tools (Wiz/Prisma/AccuKnox)"
  }
}

run "extra_apis_are_merged_into_enabled_set" {
  command = plan

  variables {
    extra_apis = ["secretmanager.googleapis.com"]
  }

  assert {
    condition     = contains(module.apis.enabled_apis, "secretmanager.googleapis.com")
    error_message = "extra_apis must be merged into the enabled set"
  }

  assert {
    condition     = contains(module.apis.enabled_apis, "container.googleapis.com")
    error_message = "required APIs must still be present when extra_apis is set"
  }
}
