#!/usr/bin/env bats

# Load bats helpers
load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'

load 'helpers'

setup_alias_mocks() {
  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/v1/servers/123/sites" \
    "get_sites_without_existing_site.json"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/v1/servers/123/sites" \
    "post_create_site.json"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/git" \
    "post_setup_site_git.json"

  mock_curl_response \
    "PUT" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/env" \
    "put_update_site_env.json"

  mock_curl_response \
    "PUT" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/deployment/script" \
    "put_update_site_deployment_script.json"

  mock_curl_response \
    "POST" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/deployment/deploy" \
    "post_deploy_site.json"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1" \
    "get_site.json"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/deployment-history" \
    "get_successful_site_deployment_history.json"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/deployment-history/71/output" \
    "get_successful_site_deployment_history_output.json"
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
  setup_alias_mocks

  export INPUT_LETSENCRYPT_CERTIFICATE="false"
  export INPUT_ROOT_DOMAIN="example.com"
  export INPUT_ALIASES="www, api"
  export GITHUB_REF_NAME="pull/123/merge"
  export INPUT_BRANCH="feature-branch"
  export INPUT_HOST="123-feature-branch.example.com"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  assert_output --partial "Processing aliases: www, api"
  assert_output --partial "Created alias: www.123-feature-branch.example.com"
  assert_output --partial "Created alias: api.123-feature-branch.example.com"
  assert_output --partial "All domains for certificate: 123-feature-branch.example.com,www.123-feature-branch.example.com,api.123-feature-branch.example.com"
  assert_output --partial '"aliases": ["www.123-feature-branch.example.com", "api.123-feature-branch.example.com"]'
}

@test "generates aliases for hostname without root domain" {
  setup_alias_mocks

  export INPUT_LETSENCRYPT_CERTIFICATE="false"
  export INPUT_ROOT_DOMAIN=""
  export INPUT_ALIASES="mobile, admin"
  export GITHUB_REF_NAME="pull/456/merge"
  export INPUT_BRANCH="fix-bug"
  export INPUT_HOST="123-fix-bug"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  assert_output --partial "Processing aliases: mobile, admin"
  assert_output --partial "Created alias: mobile-123-fix-bug"
  assert_output --partial "Created alias: admin-123-fix-bug"
  assert_output --partial "All domains for certificate: 123-fix-bug,mobile-123-fix-bug,admin-123-fix-bug"
  assert_output --partial '"aliases": ["mobile-123-fix-bug", "admin-123-fix-bug"]'
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
  setup_alias_mocks

  export INPUT_LETSENCRYPT_CERTIFICATE="false"
  export INPUT_HOST="custom-host.staging.com"
  export INPUT_ALIASES="www, api, dashboard"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  assert_output --partial "Processing aliases: www, api, dashboard"
  assert_output --partial "Created alias: www.custom-host.staging.com"
  assert_output --partial "Created alias: api.custom-host.staging.com"
  assert_output --partial "Created alias: dashboard.custom-host.staging.com"
}

@test "trims whitespace from aliases" {
  setup_alias_mocks

  export INPUT_LETSENCRYPT_CERTIFICATE="false"
  export INPUT_HOST="app.test.com"
  export INPUT_ALIASES="  www  , api   ,   mobile"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  assert_output --partial "Created alias: www.app.test.com"
  assert_output --partial "Created alias: api.app.test.com"
  assert_output --partial "Created alias: mobile.app.test.com"
}

@test "works without aliases" {
  setup_alias_mocks

  export INPUT_LETSENCRYPT_CERTIFICATE="false"
  export INPUT_HOST="simple.com"
  export INPUT_ALIASES=""

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  refute_output --partial "Processing aliases"
}

@test "ignores empty aliases in comma-separated list" {
  setup_alias_mocks

  export INPUT_LETSENCRYPT_CERTIFICATE="false"
  export INPUT_HOST="test.com"
  export INPUT_ALIASES="www, , api"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  assert_output --partial "Created alias: www.test.com"
  assert_output --partial "Created alias: api.test.com"
  assert_output --partial "All domains for certificate: test.com,www.test.com,api.test.com"
}

@test "handles single alias correctly" {
  setup_alias_mocks

  export INPUT_LETSENCRYPT_CERTIFICATE="false"
  export INPUT_HOST="single.example.com"
  export INPUT_ALIASES="www"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  assert_output --partial "Processing aliases: www"
  assert_output --partial "Created alias: www.single.example.com"
  assert_output --partial "All domains for certificate: single.example.com,www.single.example.com"
}

@test "correctly combines main domain with aliases for certificate" {
  setup_alias_mocks

  export INPUT_LETSENCRYPT_CERTIFICATE="false"
  export INPUT_HOST="api-test.example.com"
  export INPUT_ALIASES="www, admin"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"
  assert_success

  assert_output --partial "Processing aliases: www, admin"
  assert_output --partial "Created alias: www.api-test.example.com"
  assert_output --partial "Created alias: admin.api-test.example.com"
  assert_output --partial "All domains for certificate: api-test.example.com,www.api-test.example.com,admin.api-test.example.com"
}

