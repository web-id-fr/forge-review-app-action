#!/usr/bin/env bats

# Load bats helpers
load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'

load 'helpers'

setup_alias_mocks() {
  local host="$1"

  mock_curl_response_sequence \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites?filter%5Bname%5D=$host" \
    "get_sites_without_existing_site.json"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites" \
    "post_create_site.json" \
    "202"

  # Poll after creation, same URL as the existence check above (GET /sites/{id}
  # isn't supported by the Forge API v2) - site now found and installed.
  mock_curl_response_sequence \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites?filter%5Bname%5D=$host" \
    "get_sites_with_existing_site.json"

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
}

setup_alias_certificate_mocks() {
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
}

setup() {
  setup_workspace
  setup_curl_mock
}

teardown() {
  teardown_curl_mock
  teardown_workspace
}

@test "generates aliases for FQDN host with root domain" {
  export INPUT_LETSENCRYPT_CERTIFICATE="false"
  export INPUT_ROOT_DOMAIN="example.com"
  export INPUT_ALIASES="www, api"
  export GITHUB_REF_NAME="pull/123/merge"
  export INPUT_BRANCH="feature-branch"
  export INPUT_HOST="123-feature-branch.example.com"

  setup_alias_mocks "$INPUT_HOST"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  assert_output --partial "Processing aliases: www, api"
  assert_output --partial "Created alias: www.123-feature-branch.example.com"
  assert_output --partial "Created alias: api.123-feature-branch.example.com"
  assert_output --partial "Create domain '123-feature-branch.example.com'"
  assert_output --partial "Create domain 'www.123-feature-branch.example.com'"
  assert_output --partial "Create domain 'api.123-feature-branch.example.com'"
}

@test "generates aliases for hostname without root domain" {
  export INPUT_LETSENCRYPT_CERTIFICATE="false"
  export INPUT_ROOT_DOMAIN=""
  export INPUT_ALIASES="mobile, admin"
  export GITHUB_REF_NAME="pull/456/merge"
  export INPUT_BRANCH="fix-bug"
  export INPUT_HOST="123-fix-bug"

  setup_alias_mocks "$INPUT_HOST"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  assert_output --partial "Processing aliases: mobile, admin"
  assert_output --partial "Created alias: mobile-123-fix-bug"
  assert_output --partial "Created alias: admin-123-fix-bug"
}

@test "validates alias format and rejects invalid characters" {
  export INPUT_HOST="test.com"
  export INPUT_ALIASES="invalid@alias"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_failure

  assert_output --partial "Error: Invalid alias 'invalid@alias'"
}

@test "validates alias format and rejects leading hyphen" {
  export INPUT_HOST="test.com"
  export INPUT_ALIASES="-invalid"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_failure

  assert_output --partial "Error: Invalid alias '-invalid'"
}

@test "validates alias format and rejects trailing hyphen" {
  export INPUT_HOST="test.com"
  export INPUT_ALIASES="invalid-"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_failure

  assert_output --partial "Error: Invalid alias 'invalid-'"
}

@test "handles predefined host with aliases" {
  export INPUT_LETSENCRYPT_CERTIFICATE="false"
  export INPUT_HOST="custom-host.staging.com"
  export INPUT_ALIASES="www, api, dashboard"

  setup_alias_mocks "$INPUT_HOST"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  assert_output --partial "Processing aliases: www, api, dashboard"
  assert_output --partial "Created alias: www.custom-host.staging.com"
  assert_output --partial "Created alias: api.custom-host.staging.com"
  assert_output --partial "Created alias: dashboard.custom-host.staging.com"
}

@test "trims whitespace from aliases" {
  export INPUT_LETSENCRYPT_CERTIFICATE="false"
  export INPUT_HOST="app.test.com"
  export INPUT_ALIASES="  www  , api   ,   mobile"

  setup_alias_mocks "$INPUT_HOST"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  assert_output --partial "Created alias: www.app.test.com"
  assert_output --partial "Created alias: api.app.test.com"
  assert_output --partial "Created alias: mobile.app.test.com"
}

@test "works without aliases" {
  export INPUT_LETSENCRYPT_CERTIFICATE="false"
  export INPUT_HOST="simple.com"
  export INPUT_ALIASES=""

  setup_alias_mocks "$INPUT_HOST"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  refute_output --partial "Processing aliases"
}

@test "ignores empty aliases in comma-separated list" {
  export INPUT_LETSENCRYPT_CERTIFICATE="false"
  export INPUT_HOST="test.com"
  export INPUT_ALIASES="www, , api"

  setup_alias_mocks "$INPUT_HOST"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  assert_output --partial "Created alias: www.test.com"
  assert_output --partial "Created alias: api.test.com"
}

@test "handles single alias correctly" {
  export INPUT_LETSENCRYPT_CERTIFICATE="false"
  export INPUT_HOST="single.example.com"
  export INPUT_ALIASES="www"

  setup_alias_mocks "$INPUT_HOST"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  assert_output --partial "Processing aliases: www"
  assert_output --partial "Created alias: www.single.example.com"
}

@test "correctly combines main domain with aliases for certificate" {
  export INPUT_HOST="api-test.example.com"
  export INPUT_ALIASES="www, admin"

  setup_alias_mocks "$INPUT_HOST"
  setup_alias_certificate_mocks

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  assert_output --partial "Processing aliases: www, admin"
  assert_output --partial "Created alias: www.api-test.example.com"
  assert_output --partial "Created alias: admin.api-test.example.com"
  assert_output --partial "Obtain Let's Encrypt certificate for 'api-test.example.com'"
  assert_output --partial "Obtain Let's Encrypt certificate for 'www.api-test.example.com'"
  assert_output --partial "Obtain Let's Encrypt certificate for 'admin.api-test.example.com'"
}
