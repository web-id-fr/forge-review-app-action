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
      "https://forge.laravel.com/api/orgs/test-org/servers/123/sites?filter%5Bname%5D=1-test-branch" \
      "get_sites_without_existing_site.json"
  else
    mock_curl_response \
      "GET" \
      "https://forge.laravel.com/api/orgs/test-org/servers/123/sites?filter%5Bname%5D=1-test-branch" \
      "get_sites_with_existing_site.json"
  fi

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/database/schemas?filter%5Bname%5D=1_test_branch" \
    "get_databases_without_existing_database.json"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/database/schemas" \
    "post_create_database.json" \
    "202"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/database/schemas/1" \
    "get_database_status_installed.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites" \
    "post_create_site.json" \
    "202"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1" \
    "get_site_status_installed.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/deployments/push-to-deploy" \
    "successful_enable_site_quick_deployment.json" \
    "202"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/domains" \
    "get_site_domains_empty.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/domains" \
    "post_create_domain.json" \
    "202"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/domains/10/certificates" \
    "get_domain_certificates_empty.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/domains/10/certificates" \
    "post_create_certificate.json" \
    "202"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/domains/10/certificates/100" \
    "get_certificate_status_installed.json" \
    "200"

  mock_curl_response \
    "PUT" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/environment" \
    "put_update_site_env.json" \
    "202"

  mock_curl_response \
    "PUT" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/deployments/script" \
    "put_update_site_deployment_script.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/deployments" \
    "post_deploy_site.json" \
    "202"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/deployments/status" \
    "get_deployment_status_finished.json" \
    "200"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/deployments?sort=-created_at&page%5Bsize%5D=1" \
    "get_last_deployment.json" \
    "200"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/deployments/71/log" \
    "get_deployment_log.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/integrations/horizon" \
    "successful_site_laravel_horizon_integration.json" \
    "202"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/integrations/laravel-scheduler" \
    "successful_site_laravel_scheduler_integration.json" \
    "202"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/background-processes?filter%5Bsite_id%5D=1" \
    "get_background_processes_empty.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/background-processes" \
    "post_create_site_worker.json" \
    "202"

  mock_curl_response \
    "DELETE" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/background-processes/5" \
    "delete_site_worker.json" \
    "202"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/security-rules" \
    "get_security_rules_empty.json" \
    "200"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/security-rules" \
    "post_create_site_security_rule.json" \
    "202"

  mock_curl_response \
    "DELETE" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/security-rules/7" \
    "delete_site_security_rule.json" \
    "202"
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
  assert_output --partial "New database (ID 1) created successfully"
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

@test "Repository configured on Forge site" {
  setup_successful_common_curl_mocks

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Repository configured on Forge site (git@github.com:owner/repo.git)"
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

@test "Security rule (ID 7) created successfully" {
  setup_successful_common_curl_mocks

  export INPUT_SECURITY_RULE_ENABLED="true"
  export INPUT_SECURITY_RULE_USERNAME="admin"
  export INPUT_SECURITY_RULE_PASSWORD="s3cret"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Security rule not found"
  assert_output --partial "Security rule (ID 7) created successfully"
}

@test "Laravel Scheduler integration enabled successfully" {
  setup_successful_common_curl_mocks

  export INPUT_SCHEDULER_ENABLED="true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Laravel Scheduler integration enabled successfully"
}

@test "Fails to enable Laravel Scheduler integration when HTTP status is not 202" {
  setup_successful_common_curl_mocks

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/integrations/laravel-scheduler" \
    "successful_site_laravel_scheduler_integration.json" \
    "201"

  export INPUT_SCHEDULER_ENABLED="true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_failure
  assert_output --partial "Failed to enable Laravel Scheduler integration. HTTP status code: 201"
}

@test "Enable quick deployment successfully" {
  setup_successful_common_curl_mocks

  export INPUT_QUICK_DEPLOY_ENABLED="true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Enabled quick deployment successfully"
}

@test "Fails to enable quick deployment when HTTP status is not 202" {
  setup_successful_common_curl_mocks

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites/1/deployments/push-to-deploy" \
    "successful_enable_site_quick_deployment.json" \
    "201"

  export INPUT_QUICK_DEPLOY_ENABLED="true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_failure
  assert_output --partial "Failed to enable quick deployment. HTTP status code: 201"
}

@test "Worker (ID 5) created successfully" {
  setup_successful_common_curl_mocks

  export INPUT_CREATE_WORKER="true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Worker (ID 5) created successfully"
}

@test "Worker (ID 5) recreated when configuration changed" {
  setup_successful_common_curl_mocks

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/background-processes?filter%5Bsite_id%5D=1" \
    "get_background_processes_different.json" \
    "200"

  export INPUT_CREATE_WORKER="true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Worker (ID 5) deleted successfully"
  assert_output --partial "Worker (ID 5) created successfully"
}

@test "Worker (ID 5) kept unchanged when configuration matches" {
  setup_successful_common_curl_mocks

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/background-processes?filter%5Bsite_id%5D=1" \
    "get_background_processes_matching.json" \
    "200"

  export INPUT_CREATE_WORKER="true"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  #debug_output

  assert_success
  assert_output --partial "Background process found"
  refute_output --partial "Worker (ID 5) deleted successfully"
  refute_output --partial "Worker (ID 5) created successfully"
}
