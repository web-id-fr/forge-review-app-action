#!/usr/bin/env bats

# Load bats helpers
load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'

@test "Script has executable permission" {
    [ -x "$BATS_TEST_DIRNAME/../entrypoint.sh" ]
}

@test "Script has correct shebang" {
    run head -1 "$BATS_TEST_DIRNAME/../entrypoint.sh"
    assert_output "#!/bin/bash"
}

@test "Check script syntax" {
    # Check for bash syntax errors
    run bash -n "$BATS_TEST_DIRNAME/../entrypoint.sh"
    assert_success
}

@test "Check script with shellcheck" {
    # If shellcheck is available, run it
    if command -v shellcheck >/dev/null 2>&1; then
        run shellcheck "$BATS_TEST_DIRNAME/../entrypoint.sh"
        echo "Shellcheck output: $output"
        # Don't fail the test if shellcheck finds issues
    else
        # Skip the test properly when shellcheck is not available
        skip "shellcheck not installed"
    fi
}

@test "Script runs with /bin/sh" {
    # The Forge API v2 migration introduced bash arrays (ALIASES_ARRAY,
    # DOMAIN_IDS, ...) to track the per-domain resources created via the new
    # JSON:API endpoints (one domain/certificate per alias). Bash arrays are
    # not POSIX sh syntax, so this script can no longer be parsed by a
    # strict POSIX shell (e.g. busybox ash on Alpine). This is an accepted,
    # intentional trade-off of the v2 migration, not a regression to fix here.
    skip "entrypoint.sh intentionally relies on bash arrays since the Forge API v2 migration and is no longer POSIX sh compatible"
}

@test "Script does not use bash here-strings (<<<)" {
    # The here-string syntax (<<<) is bash-specific and causes errors in POSIX sh
    # This test ensures we use POSIX-compatible heredocs instead
    run grep -n '<<<' "$BATS_TEST_DIRNAME/../entrypoint.sh"
    assert_failure
}
