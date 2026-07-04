variables {
  gcp_project_id = "test-project"
}

run "plan" {
  command = plan
  assert {
    condition     = google_project_service.gcp_project_id.id == "replace-me"
    error_message = "project is not replace-me"
  }
}
