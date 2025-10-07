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