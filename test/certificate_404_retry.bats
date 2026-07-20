#!/usr/bin/env bats

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

@test "Certificate polling retries on 404 instead of failing immediately" {
  mock_curl_response_sequence \
    "GET" \
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites?filter%5Bname%5D=1-test-branch.test.com" \
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
    "https://forge.laravel.com/api/orgs/test-org/servers/123/sites?filter%5Bname%5D=1-test-branch.test.com" \
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
    "get_certificate_404.json" \
    "404"

  export INPUT_HOST="1-test-branch.test.com"
  export INPUT_ENV_STUB_PATH=".github/workflows/.env.stub"
  export INPUT_DEPLOY_SCRIPT_STUB_PATH=".github/workflows/deploy-script.stub"
  export INPUT_DATABASE_NAME="test_db"
  export INPUT_DATABASE_USER="test_user"
  export INPUT_DATABASE_PASSWORD="test_pass"
  export INPUT_COMPOSER="false"
  export INPUT_ALIASES=""
  export INPUT_QUICK_DEPLOY_ENABLED="false"
  export INPUT_CERTIFICATE_SETUP_TIMEOUT="10"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  assert_output --partial "Response code 404, retrying in 5 seconds..."
  assert_output --partial "Timeout reached, exiting retry loop."

  assert_failure
}
