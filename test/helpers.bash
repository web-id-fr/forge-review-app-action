#!/bin/bash

setup_workspace() {
    export TEST_TMP_DIR="$BATS_TEST_TMPDIR"
    export GITHUB_WORKSPACE="$TEST_TMP_DIR"
    cd "$GITHUB_WORKSPACE"

    mkdir -p "$GITHUB_WORKSPACE/.github/workflows"
    echo "APP_URL=test" > "$GITHUB_WORKSPACE/.github/workflows/.env.stub"
    echo "test" > "$GITHUB_WORKSPACE/.github/workflows/deploy-script.stub"

        # Create stub files in the test workspace
        mkdir -p "$GITHUB_WORKSPACE/.github/workflows"
    cat > "$GITHUB_WORKSPACE/.github/workflows/.env.stub" << 'EOF'
APP_NAME="STUB_HOST"
APP_ENV=reviewapp
APP_KEY=
APP_DEBUG=true
APP_URL=https://STUB_HOST
APP_TIMEZONE=UTC
APP_VERSION=

APP_LOCALE=fr
APP_FALLBACK_LOCALE=en
APP_FAKER_LOCALE=en_US

APP_MAINTENANCE_DRIVER=file
APP_MAINTENANCE_STORE=database

BCRYPT_ROUNDS=12

LOG_CHANNEL=daily
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE='STUB_DATABASE_NAME'
DB_USERNAME='STUB_DATABASE_USER'
DB_PASSWORD='STUB_DATABASE_PASSWORD'

BROADCAST_CONNECTION=log
CACHE_DRIVER=array
FILESYSTEM_DISK=local
QUEUE_CONNECTION=sync

SESSION_DRIVER=file
SESSION_LIFETIME=120
SESSION_ENCRYPT=false
SESSION_PATH=/
SESSION_DOMAIN=null

CACHE_STORE=database
CACHE_PREFIX=

MEMCACHED_HOST=127.0.0.1

REDIS_CLIENT=phpredis
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=127.0.0.1
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="${APP_NAME}"

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=
AWS_USE_PATH_STYLE_ENDPOINT=false

VITE_APP_NAME="${APP_NAME}"
EOF

    cat > "$GITHUB_WORKSPACE/.github/workflows/deploy-script.stub" << 'EOF'
cd /home/forge/STUB_HOST
git fetch
git reset --hard origin/$FORGE_SITE_BRANCH

sed -i -e "s#APP_VERSION=.*#APP_VERSION='$(git rev-parse --short HEAD)'#" .env

$FORGE_COMPOSER install --no-ansi --no-interaction --no-plugins --no-progress --no-suggest --optimize-autoloader
$FORGE_PHP artisan migrate --force
$FORGE_PHP artisan key:generate
$FORGE_PHP artisan migrate:fresh --seed --force
$FORGE_PHP artisan optimize:clear
$FORGE_PHP artisan optimize
$FORGE_PHP artisan storage:link
EOF

    # Set required environment variables
    export DEBUG="true"
    export GITHUB_ACTIONS="true"
    export GITHUB_OUTPUT="$TEST_TMP_DIR/output.txt"
    export GITHUB_REPOSITORY="owner/repo"
    export GITHUB_HEAD_REF="test-branch"
    export GITHUB_REF_NAME="test-branch-1"
    export INPUT_FORGE_ORGANIZATION="test-org"
    export INPUT_FORGE_SERVER_ID="123"
    export INPUT_FORGE_API_TOKEN="test-token"
    export INPUT_BRANCH="test-branch"
}

teardown_workspace() {
    rm -rf "$TEST_TMP_DIR"
}

setup_curl_mock() {
    # Create temporary directory for mock
    export MOCK_DIR="$BATS_TEST_TMPDIR/curl_mock"
    mkdir -p "$MOCK_DIR"

    # Create the mock curl script
    cat > "$MOCK_DIR/curl" << EOF
#!/bin/bash
set -e

FIXTURES_DIR="$BATS_TEST_DIRNAME/fixtures"
MOCK_RESPONSES_FILE="$BATS_TEST_DIRNAME/.curl_mock_responses"
MOCK_STATUS_CODES_FILE="$BATS_TEST_DIRNAME/.curl_status_codes"
MOCK_SEQUENCE_RESPONSES_FILE="$BATS_TEST_DIRNAME/.curl_mock_sequence_responses"
MOCK_SEQUENCE_STATUS_CODES_FILE="$BATS_TEST_DIRNAME/.curl_mock_sequence_status_codes"

# Parse arguments to find method, URL, and output file
method="GET"
url=""
output_file=""
write_status_code=false
status_code=200  # Default status code

args=("\$@")

# Parse all arguments
for ((i=0; i<\${#args[@]}; i++)); do
    case "\${args[i]}" in
        -X|--request)
            method="\${args[i+1]}"
            ((i++))
            ;;
        -o)
            output_file="\${args[i+1]}"
            ((i++))
            ;;
        -w)
            if [[ "\${args[i+1]}" == *"%{http_code}"* ]]; then
                write_status_code=true
            fi
            ((i++))
            ;;
        http://*|https://*)
            url="\${args[i]}"
            ;;
    esac
done

# If no URL found, check all arguments
if [[ -z "\$url" ]]; then
    for arg in "\${args[@]}"; do
        if [[ "\$arg" =~ ^https?:// ]]; then
            url="\$arg"
            break
        fi
    done
fi

response_key="\${method}|\${url}"

# Sequence mocks (registered via mock_curl_response_sequence) serve one
# response per call to the same key, in order, then keep repeating the last
# one - this lets a test simulate a poll loop (e.g. "not found" on the first
# call to a URL, "installed" on the next call to that same URL). Checked
# first; if none are registered for this key, fall back to the regular
# single-value mock below (last registration wins, unaffected by call count).
sequence_responses=()
if [[ -f "\$MOCK_SEQUENCE_RESPONSES_FILE" ]]; then
    while IFS= read -r line; do
        if [[ "\$line" == "\${response_key}="* ]]; then
            sequence_responses+=("\${line#"\${response_key}="}")
        fi
    done < "\$MOCK_SEQUENCE_RESPONSES_FILE"
fi

mock_response_file=""

if [[ \${#sequence_responses[@]} -gt 0 ]]; then
    sequence_status_codes=()
    if [[ -f "\$MOCK_SEQUENCE_STATUS_CODES_FILE" ]]; then
        while IFS= read -r line; do
            if [[ "\$line" == "\${response_key}="* ]]; then
                sequence_status_codes+=("\${line#"\${response_key}="}")
            fi
        done < "\$MOCK_SEQUENCE_STATUS_CODES_FILE"
    fi

    call_count_file="\$BATS_TEST_TMPDIR/.curl_call_count_\$(echo -n "\$response_key" | cksum | cut -d' ' -f1)"
    call_index=0
    [[ -f "\$call_count_file" ]] && call_index="\$(cat "\$call_count_file")"
    [[ "\$call_index" -ge \${#sequence_responses[@]} ]] && call_index=\$((\${#sequence_responses[@]} - 1))

    mock_response_file="\${sequence_responses[\$call_index]}"
    if [[ -n "\$mock_response_file" && "\$mock_response_file" != /* ]]; then
        mock_response_file="\$FIXTURES_DIR/\$mock_response_file"
    fi

    if [[ \${#sequence_status_codes[@]} -gt 0 ]]; then
        status_index="\$call_index"
        [[ "\$status_index" -ge \${#sequence_status_codes[@]} ]] && status_index=\$((\${#sequence_status_codes[@]} - 1))
        status_code="\${sequence_status_codes[\$status_index]}"
    fi

    echo "\$((call_index + 1))" > "\$call_count_file"
else
    # Find the mock response file (last matching registration wins, so a test
    # can override a response registered earlier by a shared setup helper)
    if [[ -f "\$MOCK_RESPONSES_FILE" ]]; then
        while IFS= read -r line; do
            if [[ "\$line" == "\${response_key}="* ]]; then
                mock_response_file="\${line#"\${response_key}="}"
            fi
        done < "\$MOCK_RESPONSES_FILE"
        if [[ -n "\$mock_response_file" && "\$mock_response_file" != /* ]]; then
            mock_response_file="\$FIXTURES_DIR/\$mock_response_file"
        fi
    fi

    # Find the status code for this request (last matching registration wins)
    if [[ -f "\$MOCK_STATUS_CODES_FILE" ]]; then
        while IFS= read -r line; do
            if [[ "\$line" == "\${response_key}="* ]]; then
                status_code="\${line#"\${response_key}="}"
            fi
        done < "\$MOCK_STATUS_CODES_FILE"
    fi
fi

# Check if mock response file exists
if [[ -z "\$mock_response_file" ]]; then
    echo "Error: No mock response configured for: \$method \$url" >&2
    exit 1
fi

if [[ ! -f "\$mock_response_file" ]]; then
    echo "Error: Mock response file not found: \$mock_response_file" >&2
    exit 1
fi

# Read the mock response
mock_response="\$(cat "\$mock_response_file")"

# Handle output file and status code
if [[ -n "\$output_file" ]]; then
    echo "\$mock_response" > "\$output_file"
fi

if [[ "\$write_status_code" == "true" ]]; then
    echo "\$status_code"
else
    echo "\$mock_response"
fi

exit 0
EOF

    chmod +x "$MOCK_DIR/curl"
    export PATH="$MOCK_DIR:$PATH"

    # Clean up any existing response files
    rm -f "$BATS_TEST_DIRNAME/.curl_mock_responses" "$BATS_TEST_DIRNAME/.curl_status_codes" \
        "$BATS_TEST_DIRNAME/.curl_mock_sequence_responses" "$BATS_TEST_DIRNAME/.curl_mock_sequence_status_codes"
}

# Mock response with status code
mock_curl_response() {
    local method="$1"
    local url="$2"
    local response_file="$3"
    local status_code="${4:-200}"  # Default to 200 if not provided

    echo "${method}|${url}=${response_file}" >> "$BATS_TEST_DIRNAME/.curl_mock_responses"
    echo "${method}|${url}=${status_code}" >> "$BATS_TEST_DIRNAME/.curl_status_codes"
}

# Register a response served only on the Nth call to this method+URL, then
# repeated for any further call - use for polling loops where the same URL is
# hit multiple times expecting different responses (e.g. "not found" then
# "installed"). Unlike mock_curl_response, repeated registrations for the same
# key do NOT override each other - they queue up in call order.
mock_curl_response_sequence() {
    local method="$1"
    local url="$2"
    local response_file="$3"
    local status_code="${4:-200}"

    echo "${method}|${url}=${response_file}" >> "$BATS_TEST_DIRNAME/.curl_mock_sequence_responses"
    echo "${method}|${url}=${status_code}" >> "$BATS_TEST_DIRNAME/.curl_mock_sequence_status_codes"
}

# Mock default response (optional)
mock_curl_default() {
    local response_file="$1"
    local status_code="${2:-200}"
    echo "default=${response_file}" >> "$BATS_TEST_DIRNAME/.curl_mock_responses"
    echo "default=${status_code}" >> "$BATS_TEST_DIRNAME/.curl_status_codes"
}

teardown_curl_mock() {
    if [[ -n "$MOCK_DIR" && -d "$MOCK_DIR" ]]; then
        rm -rf "$MOCK_DIR"
    fi
    rm -f "$BATS_TEST_DIRNAME/.curl_mock_responses" "$BATS_TEST_DIRNAME/.curl_status_codes" \
        "$BATS_TEST_DIRNAME/.curl_mock_sequence_responses" "$BATS_TEST_DIRNAME/.curl_mock_sequence_status_codes"
    unset MOCK_DIR
}

debug_output() {
    # Always show output to FD 3 (won't interfere with assertions)
    echo "--- DEBUG OUTPUT START ---" >&3
    echo "$output" >&3
    echo "---  DEBUG OUTPUT END  ---" >&3
}