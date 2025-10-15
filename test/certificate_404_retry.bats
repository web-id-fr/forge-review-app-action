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
  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/v1/servers/123/sites" \
    "get_sites_without_existing_site.json"

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
    "https://forge.laravel.com/api/v1/servers/123/sites/1/certificates/letsencrypt" \
    "post_create_site_letsencrypt_certificate.json" \
    "200"

  mock_curl_response \
    "GET" \
    "https://forge.laravel.com/api/v1/servers/123/sites/1/certificates/1" \
    "get_certificate_404.json" \
    "404"

  export INPUT_HOST="1-test-branch.test.com"
  export INPUT_ENV_STUB_PATH=".github/workflows/.env.stub"
  export INPUT_DEPLOY_SCRIPT_STUB_PATH=".github/workflows/deploy-script.stub"
  export INPUT_DATABASE_NAME="test_db"
  export INPUT_DATABASE_USER="test_user"
  export INPUT_DATABASE_PASSWORD="test_pass"
  export INPUT_INSTALL_COMPOSER_DEPENDENCIES="false"
  export INPUT_CREATE_SUBDOMAIN="true"
  export INPUT_ALIASES=""
  export INPUT_ENABLE_QUICK_DEPLOY="false"
  export INPUT_CERTIFICATE_SETUP_TIMEOUT="10"

  run "$BATS_TEST_DIRNAME/../entrypoint.sh"

  assert_output --partial "Response code 404, retrying in 5 seconds..."
  assert_output --partial "Timeout reached, exiting retry loop."

  assert_failure
}
