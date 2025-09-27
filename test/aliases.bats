#!/usr/bin/env bats

load '../node_modules/bats-mock/stub'

setup() {
    stub curl
    stub jq
    stub test : 'exit 0'
    stub cp
    stub cat
    stub grep : 'echo 123'

    export INPUT_FORGE_API_TOKEN="fake-token"
    export INPUT_FORGE_SERVER_ID="12345"
    export INPUT_LETSENCRYPT_CERTIFICATE="false"
    export INPUT_CREATE_DATABASE="false"
    export INPUT_CONFIGURE_REPOSITORY="false"
    export INPUT_ENV_STUB_PATH=".env.stub"
    export INPUT_DEPLOY_SCRIPT_STUB_PATH="deploy-script.stub"
    export DEBUG="true"

    cd "$BATS_TEST_TMPDIR"
}

teardown() {
    unstub curl || true
    unstub jq || true
    unstub test || true
    unstub cp || true
    unstub cat || true
    unstub grep || true
}

@test "generates aliases for FQDN host with root domain" {
    export INPUT_ROOT_DOMAIN="example.com"
    export INPUT_ALIASES="www, api"
    export GITHUB_REF_NAME="pull/123/merge"
    export INPUT_BRANCH="feature-branch"
    export INPUT_HOST="123-feature-branch.example.com"

    run "$BATS_TEST_DIRNAME/../entrypoint.sh" 2>&1

    [[ "$output" =~ "Processing aliases: www, api" ]]
    [[ "$output" =~ "Created alias: www.123-feature-branch.example.com" ]]
    [[ "$output" =~ "Created alias: api.123-feature-branch.example.com" ]]
    [[ "$output" =~ "All domains for certificate: 123-feature-branch.example.com,www.123-feature-branch.example.com,api.123-feature-branch.example.com" ]]
}

@test "generates aliases for hostname without root domain" {
    export INPUT_ROOT_DOMAIN=""
    export INPUT_ALIASES="mobile, admin"
    export GITHUB_REF_NAME="pull/456/merge"
    export INPUT_BRANCH="fix-bug"
    export INPUT_HOST="123-fix-bug"

    run "$BATS_TEST_DIRNAME/../entrypoint.sh" 2>&1

    [[ "$output" =~ "Processing aliases: mobile, admin" ]]
    [[ "$output" =~ "Created alias: mobile-123-fix-bug" ]]
    [[ "$output" =~ "Created alias: admin-123-fix-bug" ]]
    [[ "$output" =~ "All domains for certificate: 123-fix-bug,mobile-123-fix-bug,admin-123-fix-bug" ]]
}

@test "validates alias format and rejects invalid characters" {
    export INPUT_HOST="test.com"
    export INPUT_ALIASES="invalid@alias"

    run "$BATS_TEST_DIRNAME/../entrypoint.sh" 2>&1

    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Invalid alias 'invalid@alias'" ]]
}

@test "validates alias format and rejects leading hyphen" {
    export INPUT_HOST="test.com"
    export INPUT_ALIASES="-invalid"

    run "$BATS_TEST_DIRNAME/../entrypoint.sh" 2>&1

    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Invalid alias '-invalid'" ]]
}

@test "validates alias format and rejects trailing hyphen" {
    export INPUT_HOST="test.com"
    export INPUT_ALIASES="invalid-"

    run "$BATS_TEST_DIRNAME/../entrypoint.sh" 2>&1

    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Invalid alias 'invalid-'" ]]
}

@test "handles predefined host with aliases" {
    export INPUT_HOST="custom-host.staging.com"
    export INPUT_ALIASES="www, api, dashboard"

    run "$BATS_TEST_DIRNAME/../entrypoint.sh" 2>&1

    [[ "$output" =~ "Processing aliases: www, api, dashboard" ]]
    [[ "$output" =~ "Created alias: www.custom-host.staging.com" ]]
    [[ "$output" =~ "Created alias: api.custom-host.staging.com" ]]
    [[ "$output" =~ "Created alias: dashboard.custom-host.staging.com" ]]
}

@test "trims whitespace from aliases" {
    export INPUT_HOST="app.test.com"
    export INPUT_ALIASES="  www  , api   ,   mobile"

    run "$BATS_TEST_DIRNAME/../entrypoint.sh" 2>&1

    [[ "$output" =~ "Created alias: www.app.test.com" ]]
    [[ "$output" =~ "Created alias: api.app.test.com" ]]
    [[ "$output" =~ "Created alias: mobile.app.test.com" ]]
}

@test "works without aliases" {
    export INPUT_HOST="simple.com"
    export INPUT_ALIASES=""

    run "$BATS_TEST_DIRNAME/../entrypoint.sh" 2>&1

    [[ ! "$output" =~ "Processing aliases" ]]
}

@test "ignores empty aliases in comma-separated list" {
    export INPUT_HOST="test.com"
    export INPUT_ALIASES="www, , api"

    run "$BATS_TEST_DIRNAME/../entrypoint.sh" 2>&1

    [[ "$output" =~ "Created alias: www.test.com" ]]
    [[ "$output" =~ "Created alias: api.test.com" ]]
    [[ "$output" =~ "All domains for certificate: test.com,www.test.com,api.test.com" ]]
}

@test "handles single alias correctly" {
    export INPUT_HOST="single.example.com"
    export INPUT_ALIASES="www"

    run "$BATS_TEST_DIRNAME/../entrypoint.sh" 2>&1

    [[ "$output" =~ "Processing aliases: www" ]]
    [[ "$output" =~ "Created alias: www.single.example.com" ]]
    [[ "$output" =~ "All domains for certificate: single.example.com,www.single.example.com" ]]
}

@test "correctly combines main domain with aliases for certificate" {
    export INPUT_HOST="api-test.example.com"
    export INPUT_ALIASES="www, admin"

    run "$BATS_TEST_DIRNAME/../entrypoint.sh" 2>&1

    [[ "$output" =~ "Processing aliases: www, admin" ]]
    [[ "$output" =~ "Created alias: www.api-test.example.com" ]]
    [[ "$output" =~ "Created alias: admin.api-test.example.com" ]]
    [[ "$output" =~ "All domains for certificate: api-test.example.com,www.api-test.example.com,admin.api-test.example.com" ]]

    [[ "$output" =~ "api-test.example.com,www.api-test.example.com,admin.api-test.example.com" ]]
}

@test "verifies certificate API call includes all alias domains" {
    export INPUT_HOST="cert-test.example.com"
    export INPUT_ALIASES="www, api"
    export INPUT_LETSENCRYPT_CERTIFICATE="true"
    export INPUT_CREATE_DATABASE="false"
    export INPUT_CONFIGURE_REPOSITORY="false"

    unstub curl
    unstub jq

    stub curl \
        '*sites* *cert-test.example.com*' : 'echo "{\"site\":{\"id\":999}}"' \
        '*certificates/letsencrypt* *{\"domains\":[\"cert-test.example.com\",\"www.cert-test.example.com\",\"api.cert-test.example.com\"]}*' : 'echo "{\"certificate\":{\"id\":888}}"'

    stub jq : 'echo 999'

    run "$BATS_TEST_DIRNAME/../entrypoint.sh" 2>&1

    [[ "$output" =~ "Processing aliases: www, api" ]]
    [[ "$output" =~ "All domains for certificate: cert-test.example.com,www.cert-test.example.com,api.cert-test.example.com" ]]
}

@test "verifies database creation API call uses correct database name" {
    export INPUT_HOST="db-test.example.com"
    export INPUT_ALIASES="admin"
    export INPUT_CREATE_DATABASE="true"
    export INPUT_DATABASE_PASSWORD="secret123"
    export INPUT_LETSENCRYPT_CERTIFICATE="false"
    export INPUT_CONFIGURE_REPOSITORY="false"

    unstub curl
    unstub jq

    stub curl \
        '*sites* *db-test.example.com*' : 'echo "{\"site\":{\"id\":777}}"' \
        '*databases* *db_test*' : 'echo "{\"database\":{\"id\":555}}"'

    stub jq : 'echo 777'

    run "$BATS_TEST_DIRNAME/../entrypoint.sh" 2>&1

    [[ "$output" =~ "Processing aliases: admin" ]]
    [[ "$output" =~ "Created alias: admin.db-test.example.com" ]]
}
