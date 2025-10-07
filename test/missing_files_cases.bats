#!/usr/bin/env bats

# Load bats helpers
load '../node_modules/bats-mock/stub'
load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'

load 'helpers'

setup() {
    setup_workspace
}

teardown() {
    teardown_workspace
}

@test "Script fails when .env stub is missing" {
    # Remove .env stub
    rm -f "$GITHUB_WORKSPACE/.github/workflows/.env.stub"

    run "$BATS_TEST_DIRNAME/../entrypoint.sh" 2>&1

    assert_failure
    assert_output --partial ".env stub file not found"
}

@test "Script fails when deploy script stub is missing" {
    # Remove deploy-script stub
    rm -f "$GITHUB_WORKSPACE/.github/workflows/deploy-script.stub"

    run "$BATS_TEST_DIRNAME/../entrypoint.sh" 2>&1

    assert_failure
    assert_output --partial "Deploy script stub file not found"
}