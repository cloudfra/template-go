mock_provider "google" {}
mock_provider "google-beta" {}

variables {
  gcp_project_id = "test-project"
}

run "plan" {
  command = plan

  assert {
    condition     = google_project_service.api["storage.googleapis.com"].service == "storage.googleapis.com"
    error_message = "expected the storage API to be enabled"
  }
}
