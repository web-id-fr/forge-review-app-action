#!/usr/bin/env bats

# Load bats helpers
load '../node_modules/bats-mock/stub'
load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'

load 'helpers'

setup() {
  setup_workspace
  setup_curl_mock
}

teardown() {
  teardown_curl_mock
  teardown_workspace
}

setup_successful_common_curl_mocks() {
  local existing_site="${1:-false}"

  if [[ $existing_site == "false" ]]; then
    mock_curl_response \
      "GET" \
      "https://forge.laravel.com/api/v1/servers/123/sites" \
      "get_sites_without_existing_site.json"
  else
    mock_curl_response \
      "GET" \
      "https://forge.laravel.com/api/v1/servers/123/sites" \
      "get_sites_with_existing_site.json"
  fi

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/v1/servers/123/sites" \
    "post_create_site.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/git" \
    "post_setup_site_git.json" \
    "200"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/certificates" \
    "get_site_certificates.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/certificates" \
    "post_create_site_certificate.json" \
    "200"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/certificates/1" \
    "get_site_created_certificate.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/certificates/letsencrypt" \
    "post_create_site_letsencrypt_certificate.json" \
    "200"

  mock_curl_response \
    "PUT" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/env" \
    "put_update_site_env.json" \
    "200"

  mock_curl_response \
    "PUT" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/deployment/script" \
    "put_update_site_deployment_script.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/deployment/deploy" \
    "post_deploy_site.json" \
    "200"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1" \
    "get_site.json" \
    "200"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/deployment-history" \
    "get_successful_site_deployment_history.json" \
    "200"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/deployment-history/71/output" \
    "get_successful_site_deployment_history_output.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/integrations/horizon" \
    "successful_site_laravel_horizon_integration.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/integrations/laravel-scheduler" \
    "successful_site_laravel_scheduler_integration.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/deployment" \
    "successful_enable_site_quick_deployment.json" \
    "200"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/workers" \
    "get_site_workers.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/workers" \
    "post_create_site_worker.json" \
    "200"
}

@test "New site (ID 1) created successfully" {
  setup_successful_common_curl_mocks

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "New site (ID 1) created successfully"
}

@test "New site (ID 1) and database created successfully" {
  setup_successful_common_curl_mocks

  export INPUT_CREATE_DATABASE="true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "New site (ID 1) and database created successfully"
}

@test "Site 1-test-branch not found" {
  setup_successful_common_curl_mocks

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Site 1-test-branch not found"
  assert_output --partial "New site (ID 1) created successfully"
}

@test "A site (ID 1) name match the host" {
  setup_successful_common_curl_mocks "true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "A site (ID 1) name match the host"
}

@test "Git repository configured successfully" {
  setup_successful_common_curl_mocks

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Git repository configured successfully"
}

@test "NO Check if repository is configured" {
  setup_successful_common_curl_mocks

  export INPUT_CONFIGURE_REPOSITORY="false"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  refute_output --partial "Check if repository is configured"
}

@test "Certificate installed successfully" {
  setup_successful_common_curl_mocks

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Certificate installed successfully"
}

@test ".env file updated successfully" {
  setup_successful_common_curl_mocks

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial ".env file updated successfully"
}

@test "Deployment script updated successfully" {
  setup_successful_common_curl_mocks

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Deployment script updated successfully"
}

@test "Deployment launched successfully" {
  setup_successful_common_curl_mocks

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Deployment launched successfully"
}

@test "Deployment finished successfully" {
  setup_successful_common_curl_mocks

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Deployment finished successfully"
}

@test "Laravel Horizon integration enabled successfully" {
  setup_successful_common_curl_mocks

  export INPUT_HORIZON_ENABLED="true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Laravel Horizon integration enabled successfully"
}

@test "Laravel Horizon integration enabled successfully with HTTP 201" {
  setup_successful_common_curl_mocks

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/integrations/horizon" \
    "successful_site_laravel_horizon_integration.json" \
    "201"

  export INPUT_HORIZON_ENABLED="true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Laravel Horizon integration enabled successfully"
}

@test "Laravel Scheduler integration enabled successfully" {
  setup_successful_common_curl_mocks

  export INPUT_SCHEDULER_ENABLED="true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Laravel Scheduler integration enabled successfully"
}

@test "Laravel Scheduler integration enabled successfully with HTTP 201" {
  setup_successful_common_curl_mocks

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/integrations/laravel-scheduler" \
    "successful_site_laravel_scheduler_integration.json" \
    "201"

  export INPUT_SCHEDULER_ENABLED="true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Laravel Scheduler integration enabled successfully"
}

@test "Enable quick deployment successfully" {
  setup_successful_common_curl_mocks

  export INPUT_QUICK_DEPLOY_ENABLED="true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Enable quick deployment successfully"
}

@test "Enable quick deployment successfully with HTTP 201" {
  setup_successful_common_curl_mocks

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/deployment" \
    "successful_enable_site_quick_deployment.json" \
    "201"

  export INPUT_QUICK_DEPLOY_ENABLED="true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Enable quick deployment successfully"
}

@test "Worker (ID 1) created successfully" {
  setup_successful_common_curl_mocks

  export INPUT_CREATE_WORKER="true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Worker (ID 1) created successfully"
}
