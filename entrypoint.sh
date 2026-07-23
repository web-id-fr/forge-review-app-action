#!/bin/bash
set -e

# Prepare vars and default values

if [[ -z "$DEBUG" ]]; then
  DEBUG='false'
fi

if [[ $DEBUG == 'true' ]]; then
  echo "!!! DEBUG MODE ENABLED !!!"
fi

# Use GITHUB_WORKSPACE if set, otherwise default to /github/workspace
if [[ -n "$GITHUB_WORKSPACE" ]]; then
    WORKSPACE="$GITHUB_WORKSPACE"
else
    WORKSPACE="/github/workspace"
fi

if [[ -z "$INPUT_BRANCH" ]]; then
  INPUT_BRANCH=$GITHUB_HEAD_REF
fi

ESCAPED_BRANCH=$(echo "$INPUT_BRANCH" | sed -e 's/[^a-z0-9-]/-/g' | tr -s '-')

# Remove the trailing "-" character
if [[ $ESCAPED_BRANCH == *- ]]; then
    ESCAPED_BRANCH="${ESCAPED_BRANCH%-}"
fi

if [[ -z "$INPUT_PREFIX_WITH_PR_NUMBER" ]]; then
  INPUT_PREFIX_WITH_PR_NUMBER='true'
fi

if [[ $INPUT_PREFIX_WITH_PR_NUMBER == 'true' ]]; then
  PR_NUMBER=$(echo "$GITHUB_REF_NAME" | grep -oE '[0-9]+')
  ESCAPED_BRANCH=$(echo "$PR_NUMBER-$ESCAPED_BRANCH")
fi

if [[ -z "$INPUT_HOST" ]]; then
  # Compute review-app host
  if [[ -z "$INPUT_ROOT_DOMAIN" ]]; then
    INPUT_HOST=$(echo "$ESCAPED_BRANCH")

    if [[ -n "$INPUT_FQDN_PREFIX" ]]; then
      INPUT_HOST=$(echo "$INPUT_FQDN_PREFIX$INPUT_HOST")
    fi

    # Limit to 64 chars max
    INPUT_HOST="${INPUT_HOST:0:64}"

    # Remove the trailing "-" character
    if [[ $INPUT_HOST == *- ]]; then
        INPUT_HOST="${INPUT_HOST%-}"
    fi
  else
    INPUT_HOST=$(echo "$ESCAPED_BRANCH.$INPUT_ROOT_DOMAIN")

    if [[ -n "$INPUT_FQDN_PREFIX" ]]; then
      INPUT_HOST=$(echo "$INPUT_FQDN_PREFIX$INPUT_HOST")
    fi

    # Limit to 64 chars max
    if [ ${#INPUT_HOST} -gt 64 ]; then
      INPUT_HOST=$(echo "${ESCAPED_BRANCH:0:$((${#ESCAPED_BRANCH} - $((${#INPUT_HOST} - 64))))}.$INPUT_ROOT_DOMAIN")
    fi

    # Remove dash in middle of the host
    if [[ $INPUT_HOST == *-.$INPUT_ROOT_DOMAIN ]]; then
        INPUT_HOST=$(echo "$INPUT_HOST" | sed "s/-\.$INPUT_ROOT_DOMAIN/\.$INPUT_ROOT_DOMAIN/")
    fi
  fi
fi

if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
  echo "host=$INPUT_HOST" >> $GITHUB_OUTPUT
fi

# Process aliases if provided
ALIASES_ARRAY=()
if [[ -n "$INPUT_ALIASES" ]]; then
  echo ""
  echo "* Processing aliases: $INPUT_ALIASES"

  # Convert comma-separated aliases to array and trim whitespace
  IFS=',' read -ra ALIASES << EOF
$INPUT_ALIASES
EOF

  for alias in "${ALIASES[@]}"; do
    # Trim whitespace from alias
    alias=$(echo "$alias" | xargs)

    if [[ -n "$alias" ]]; then
      # Basic validation: only allow alphanumeric characters and hyphens
      if [[ ! "$alias" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo "Error: Invalid alias '$alias'. Only alphanumeric characters and hyphens are allowed."
        exit 1
      fi

      # Validate alias doesn't start or end with hyphen
      if [[ "$alias" =~ ^- ]] || [[ "$alias" =~ -$ ]]; then
        echo "Error: Invalid alias '$alias'. Cannot start or end with hyphen."
        exit 1
      fi

      # Create alias domain by prepending alias to the main host
      if [[ "$INPUT_HOST" == *.* ]]; then
        # If host contains dots, insert alias at the beginning
        ALIAS_DOMAIN="$alias.$INPUT_HOST"
      else
        # If host is just a hostname, append alias with a dot
        ALIAS_DOMAIN="$alias-$INPUT_HOST"
      fi

      ALIASES_ARRAY+=("$ALIAS_DOMAIN")

      echo "  - Created alias: $ALIAS_DOMAIN"
    fi
  done
fi

if [[ -z "$INPUT_REPOSITORY" ]]; then
  INPUT_REPOSITORY=$GITHUB_REPOSITORY
fi

if [[ -z "$INPUT_DATABASE_NAME" ]]; then
  # Compute database name
  INPUT_DATABASE_NAME=$(echo "$ESCAPED_BRANCH" | sed -e 's/[^a-z0-9_]/_/g' | tr -s '_')
fi

if [[ -n "$INPUT_DATABASE_NAME_PREFIX" ]]; then
  INPUT_DATABASE_NAME=$(echo "$INPUT_DATABASE_NAME_PREFIX$INPUT_DATABASE_NAME")
fi

# Limit to 63 chars max
INPUT_DATABASE_NAME="${INPUT_DATABASE_NAME:0:63}"

if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
  echo "database_name=$INPUT_DATABASE_NAME" >> $GITHUB_OUTPUT
fi

AUTH_HEADER="Authorization: Bearer $INPUT_FORGE_API_TOKEN"
ACCEPT_HEADER="Accept: application/vnd.api+json"
CONTENT_TYPE_HEADER="Content-Type: application/json"

API_BASE="https://forge.laravel.com/api/orgs/$INPUT_FORGE_ORGANIZATION/servers/$INPUT_FORGE_SERVER_ID"

if [[ -z "$INPUT_PROJECT_TYPE" ]]; then
  INPUT_PROJECT_TYPE='php'
fi

# 'html' was a valid site type in the Forge API v1, renamed to 'static-html' in v2.
if [[ "$INPUT_PROJECT_TYPE" == 'html' ]]; then
  INPUT_PROJECT_TYPE='static-html'
fi

if [[ -z "$INPUT_DIRECTORY" ]]; then
  INPUT_DIRECTORY='/public'
fi

if [[ -z "$INPUT_ISOLATED" ]]; then
  INPUT_ISOLATED='false'
fi

if [[ -z "$INPUT_PHP_VERSION" ]]; then
  INPUT_PHP_VERSION='php81'
fi

if [[ -z "$INPUT_CREATE_DATABASE" ]]; then
  INPUT_CREATE_DATABASE='false'
fi

if [[ -z "$INPUT_DATABASE_USER" ]]; then
  INPUT_DATABASE_USER='forge'
fi

if [[ -z "$INPUT_CONFIGURE_REPOSITORY" ]]; then
  INPUT_CONFIGURE_REPOSITORY='true'
fi

if [[ -z "$INPUT_REPOSITORY_PROVIDER" ]]; then
  INPUT_REPOSITORY_PROVIDER='github'
fi

if [[ -z "$INPUT_COMPOSER" ]]; then
  INPUT_COMPOSER='false'
fi

if [[ -z "$INPUT_LETSENCRYPT_CERTIFICATE" ]]; then
  INPUT_LETSENCRYPT_CERTIFICATE='true'
fi

if [[ -z "$INPUT_CERTIFICATE_SETUP_TIMEOUT" ]]; then
  INPUT_CERTIFICATE_SETUP_TIMEOUT='120'
fi

if [[ -z "$INPUT_ENV_STUB_PATH" ]]; then
  INPUT_ENV_STUB_PATH='.github/workflows/.env.stub'
fi

if [[ -z "$INPUT_DEPLOY_SCRIPT_STUB_PATH" ]]; then
  INPUT_DEPLOY_SCRIPT_STUB_PATH='.github/workflows/deploy-script.stub'
fi

if [[ -z "$INPUT_DEPLOYMENT_TIMEOUT" ]]; then
  INPUT_DEPLOYMENT_TIMEOUT='120'
fi

if [[ -z "$INPUT_DEPLOYMENT_AUTO_SOURCE" ]]; then
  INPUT_DEPLOYMENT_AUTO_SOURCE='true'
fi

if [[ -z "$INPUT_CREATE_WORKER" ]]; then
  INPUT_CREATE_WORKER='false'
fi

if [[ -z "$INPUT_WORKER_CONNECTION" ]]; then
  INPUT_WORKER_CONNECTION='redis'
fi

if [[ -z "$INPUT_WORKER_TIMEOUT" ]]; then
  INPUT_WORKER_TIMEOUT='90'
fi

if [[ -z "$INPUT_WORKER_SLEEP" ]]; then
  INPUT_WORKER_SLEEP='60'
fi

if [[ -z "$INPUT_WORKER_PROCESSES" ]]; then
  INPUT_WORKER_PROCESSES='1'
fi

if [[ -z "$INPUT_WORKER_STOPWAITSECS" ]]; then
  INPUT_WORKER_STOPWAITSECS='600'
fi

if [[ -z "$INPUT_WORKER_FORCE" ]]; then
  INPUT_WORKER_FORCE='false'
fi

if [[ -z "$INPUT_HORIZON_ENABLED" ]]; then
  INPUT_HORIZON_ENABLED='false'
fi

if [[ -z "$INPUT_SCHEDULER_ENABLED" ]]; then
  INPUT_SCHEDULER_ENABLED='false'
fi

if [[ -z "$INPUT_QUICK_DEPLOY_ENABLED" ]]; then
  INPUT_QUICK_DEPLOY_ENABLED='false'
fi

if [[ -n "$INPUT_WORKER_DAEMON" || -n "$INPUT_WORKER_PHP_VERSION" ]]; then
  echo "⚠️ 'worker_daemon' and 'worker_php_version' have no equivalent in the Forge API v2 (Background Processes are always supervisor-managed and the worker command now uses the site's own 'php_version' input). These inputs are ignored."
fi

echo ""
echo "* Check that stubs files exists"

if [ ! -e "$WORKSPACE/$INPUT_ENV_STUB_PATH" ]; then
  echo ".env stub file not found at $WORKSPACE/$INPUT_ENV_STUB_PATH"
  exit 1
fi

if [ ! -e "$WORKSPACE/$INPUT_DEPLOY_SCRIPT_STUB_PATH" ]; then
  echo "Deploy script stub file not found at $WORKSPACE/$INPUT_DEPLOY_SCRIPT_STUB_PATH"
  exit 1
fi

echo ".env and deploy script stub files found"

echo ""
echo '* Get Forge server sites'
API_URL="$API_BASE/sites?filter%5Bname%5D=$INPUT_HOST"

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] CURL GET on $API_URL"
  echo ""
fi

JSON_RESPONSE=$(
  curl -s -H "$AUTH_HEADER" \
    -H "$ACCEPT_HEADER" \
    "$API_URL"
)

echo "$JSON_RESPONSE" > sites.json

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] response JSON:"
  echo "$JSON_RESPONSE"
  echo ""
fi

# Check if review-app site exists (filter[name] may be a partial match, so confirm the exact name)
SITE_DATA=$(jq -r '.data[] | select(.attributes.name == "'"$INPUT_HOST"'") // empty' sites.json)
if [[ -n "$SITE_DATA" ]]; then
  echo "$SITE_DATA" > site.json
  SITE_ID=$(jq -r '.id' site.json)

  if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
    echo "site_id=$SITE_ID" >> $GITHUB_OUTPUT
  fi

  echo "A site (ID $SITE_ID) name match the host"
  RA_FOUND='true'
else
  echo "Site $INPUT_HOST not found"
  RA_FOUND='false'
fi

if [[ $RA_FOUND == 'false' ]]; then
  DATABASE_ID=""

  if [[ $INPUT_CREATE_DATABASE == 'true' ]]; then
    echo ""
    echo "* Get Forge server databases"

    API_URL="$API_BASE/database/schemas?filter%5Bname%5D=$INPUT_DATABASE_NAME"

    JSON_RESPONSE=$(
      curl -s -H "$AUTH_HEADER" \
        -H "$ACCEPT_HEADER" \
        "$API_URL"
    )
    echo "$JSON_RESPONSE" > databases.json

    DATABASE_DATA=$(jq -r '.data[] | select(.attributes.name == "'"$INPUT_DATABASE_NAME"'") // empty' databases.json)

    if [[ -n "$DATABASE_DATA" ]]; then
      echo "$DATABASE_DATA" > database.json
      DATABASE_ID=$(jq -r '.id' database.json)
      echo "A database (ID $DATABASE_ID, NAME $INPUT_DATABASE_NAME) already exists"
    else
      echo ""
      echo "* Create review-app database"

      API_URL="$API_BASE/database/schemas"

      JSON_PAYLOAD='{
        "name": "'"$INPUT_DATABASE_NAME"'"
      }'

      if [[ $DEBUG == 'true' ]]; then
        echo "[DEBUG] CURL POST on $API_URL with payload :"
        echo "$JSON_PAYLOAD"
        echo ""
      fi

      HTTP_STATUS=$(
        curl -s -o create-database-response.json -w "%{http_code}" \
          -X POST \
          -H "$AUTH_HEADER" \
          -H "$ACCEPT_HEADER" \
          -H "$CONTENT_TYPE_HEADER" \
          -d "$JSON_PAYLOAD" \
          "$API_URL"
      )

      JSON_RESPONSE=$(cat create-database-response.json)

      if [[ $HTTP_STATUS -eq 202 ]]; then
        jq '.data' create-database-response.json > database.json
        DATABASE_ID=$(jq -r '.id' database.json)
        echo "New database (ID $DATABASE_ID) created successfully"
      else
        echo "Failed to create new database. HTTP status code: $HTTP_STATUS"
        echo "JSON Response:"
        echo "$JSON_RESPONSE"
        exit 1
      fi

      echo ""
      echo "* Wait for database to be installed"

      API_URL="$API_BASE/database/schemas/$DATABASE_ID"

      start_time=$(date +%s)
      elapsed_time=0
      status=""

      while [[ "$status" != "installed" && "$elapsed_time" -lt 120 ]]; do
        JSON_RESPONSE=$(
          curl -s -H "$AUTH_HEADER" \
            -H "$ACCEPT_HEADER" \
            "$API_URL"
        )

        status=$(echo "$JSON_RESPONSE" | jq -r '.data.attributes.status')

        if [[ "$status" != "installed" ]]; then
          echo "Database status is not \"installed\" ($status), retrying in 5 seconds..."
          sleep 5
        fi

        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
      done

      if [[ "$status" != "installed" ]]; then
        echo "Timeout reached while waiting for database installation, exiting."
        exit 1
      fi
    fi
  fi

  echo ""
  echo "* Create review-app site"

  API_URL="$API_BASE/sites"

  JSON_PAYLOAD='{
    "type": "'"$INPUT_PROJECT_TYPE"'",
    "domain_mode": "custom",
    "name": "'"$INPUT_HOST"'",
    "web_directory": "'"$INPUT_DIRECTORY"'",
    "is_isolated": '"$INPUT_ISOLATED"',
    "php_version": "'"$INPUT_PHP_VERSION"'",
    "push_to_deploy": '"$INPUT_QUICK_DEPLOY_ENABLED"',
    "www_redirect_type": "none",
    "allow_wildcard_subdomains": false'

  if [[ -n "$DATABASE_ID" ]]; then
    JSON_PAYLOAD="$JSON_PAYLOAD"',
    "database_id": '"$DATABASE_ID"''
  fi

  if [[ $INPUT_CONFIGURE_REPOSITORY == 'true' ]]; then
    JSON_PAYLOAD="$JSON_PAYLOAD"',
    "source_control_provider": "'"$INPUT_REPOSITORY_PROVIDER"'",
    "repository": "'"$INPUT_REPOSITORY"'",
    "branch": "'"$INPUT_BRANCH"'",
    "install_composer_dependencies": '"$INPUT_COMPOSER"''
  fi

  if [[ -n "$INPUT_NGINX_TEMPLATE" ]]; then
    if [[ "$INPUT_NGINX_TEMPLATE" =~ ^[0-9]+$ ]]; then
      # Numeric input: use it directly as the nginx template ID (backward-compatible
      # with existing consumers passing the raw ID, as the pre-v2 API did).
      NGINX_TEMPLATE_ID="$INPUT_NGINX_TEMPLATE"
    else
      echo ""
      echo "* Resolve nginx template ID for '$INPUT_NGINX_TEMPLATE'"

      NGINX_TEMPLATE_URL="$API_BASE/nginx/templates?filter%5Bname%5D=$INPUT_NGINX_TEMPLATE"

      NGINX_TEMPLATE_RESPONSE=$(
        curl -s -H "$AUTH_HEADER" \
          -H "$ACCEPT_HEADER" \
          "$NGINX_TEMPLATE_URL"
      )

      NGINX_TEMPLATE_ID=$(echo "$NGINX_TEMPLATE_RESPONSE" | jq -r '.data[] | select(.attributes.name == "'"$INPUT_NGINX_TEMPLATE"'") | .id' | head -n 1)

      if [[ -z "$NGINX_TEMPLATE_ID" ]]; then
        echo "Error: nginx template '$INPUT_NGINX_TEMPLATE' not found"
        exit 1
      fi
    fi

    JSON_PAYLOAD="$JSON_PAYLOAD"',
    "nginx_template_id": '"$NGINX_TEMPLATE_ID"''
  fi

  # Close JSON object
  JSON_PAYLOAD="$JSON_PAYLOAD"'
  }'

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL POST on $API_URL with payload :"
    echo "$JSON_PAYLOAD"
    echo ""
  fi

  HTTP_STATUS=$(
    curl -s -o site-create-response.json -w "%{http_code}" \
      -X POST \
      -H "$AUTH_HEADER" \
      -H "$ACCEPT_HEADER" \
      -H "$CONTENT_TYPE_HEADER" \
      -d "$JSON_PAYLOAD" \
      "$API_URL"
  )

  JSON_RESPONSE=$(cat site-create-response.json)

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] response JSON:"
    echo "$JSON_RESPONSE"
    echo ""
  fi

  if [[ $HTTP_STATUS -eq 202 ]]; then
    jq '.data' site-create-response.json > site.json
    SITE_ID=$(jq -r '.id' site.json)

    if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
      echo "site_id=$SITE_ID" >> $GITHUB_OUTPUT
    fi

    if [[ -n "$DATABASE_ID" ]]; then
      echo "New site (ID $SITE_ID) and database created successfully"
    else
      echo "New site (ID $SITE_ID) created successfully"
    fi
  else
    echo "Failed to create new site. HTTP status code: $HTTP_STATUS"
    echo "JSON Response:"
    echo "$JSON_RESPONSE"
    exit 1
  fi

  echo ""
  echo "* Wait for site to be installed"

  # GET /sites/{id} is not supported by the Forge API v2 (only PUT/DELETE), so
  # the site must be looked up by name instead.
  API_URL="$API_BASE/sites?filter%5Bname%5D=$INPUT_HOST"

  start_time=$(date +%s)
  elapsed_time=0
  status=""

  while [[ "$status" != "installed" && "$status" != "never-deployed" && "$elapsed_time" -lt 120 ]]; do
    JSON_RESPONSE=$(
      curl -s -H "$AUTH_HEADER" \
        -H "$ACCEPT_HEADER" \
        "$API_URL"
    )

    status=$(echo "$JSON_RESPONSE" | jq -r '.data[0].attributes.status')

    if [[ "$status" == "failed" ]]; then
      echo "Site installation failed"
      echo "$JSON_RESPONSE"
      exit 1
    fi

    if [[ "$status" != "installed" && "$status" != "never-deployed" ]]; then
      echo "Site status is not ready yet ($status), retrying in 5 seconds..."
      sleep 5
    fi

    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
  done

  if [[ "$status" != "installed" && "$status" != "never-deployed" ]]; then
    echo "Timeout reached while waiting for site installation, exiting."
    exit 1
  fi

  echo "$JSON_RESPONSE" | jq '.data[0]' > site.json
fi

if [[ $INPUT_CONFIGURE_REPOSITORY == 'true' ]]; then
  echo ""
  echo "* Check if repository is configured"
  SITE_REPOSITORY_URL=$(jq -r '.attributes.repository.url' site.json)

  if [[ $SITE_REPOSITORY_URL == 'null' ]]; then
    echo "⚠️ Repository is not configured on this Forge site, and the Forge API v2 has no endpoint to configure a repository on an already existing site (it can only be set at site creation). Skipping."
  else
    echo "Repository configured on Forge site ($SITE_REPOSITORY_URL)"
  fi
fi

if [[ $INPUT_QUICK_DEPLOY_ENABLED == 'true' ]]; then
  CURRENT_QUICK_DEPLOY=$(jq -r '.attributes.quick_deploy' site.json)

  if [[ "$CURRENT_QUICK_DEPLOY" != "true" ]]; then
    echo ""
    echo "* Enable quick deployment"

    API_URL="$API_BASE/sites/$SITE_ID/deployments/push-to-deploy"

    if [[ $DEBUG == 'true' ]]; then
      echo "[DEBUG] CURL POST on $API_URL"
      echo ""
    fi

    HTTP_STATUS=$(
      curl -s -o setup-site-quick-deploy-response.json -w "%{http_code}" \
        -X POST \
        -H "$AUTH_HEADER" \
        -H "$ACCEPT_HEADER" \
        "$API_URL"
    )

    JSON_RESPONSE=$(cat setup-site-quick-deploy-response.json)

    if [[ $HTTP_STATUS -eq 202 ]]; then
      echo "Enabled quick deployment successfully"
    else
      echo "Failed to enable quick deployment. HTTP status code: $HTTP_STATUS"
      echo "JSON Response:"
      echo "$JSON_RESPONSE"
      exit 1
    fi
  fi
fi

echo ""
echo "* Get site domains"

API_URL="$API_BASE/sites/$SITE_ID/domains"

JSON_RESPONSE=$(
  curl -s -H "$AUTH_HEADER" \
    -H "$ACCEPT_HEADER" \
    "$API_URL"
)
echo "$JSON_RESPONSE" > domains.json

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] response JSON:"
  echo "$JSON_RESPONSE"
  echo ""
fi

DOMAIN_IDS=()
DOMAIN_NAMES=("$INPUT_HOST" "${ALIASES_ARRAY[@]}")

for domain_name in "${DOMAIN_NAMES[@]}"; do
  DOMAIN_ID=$(jq -r '.data[] | select(.attributes.name == "'"$domain_name"'") | .id // empty' domains.json)

  if [[ -n "$DOMAIN_ID" ]]; then
    echo "Domain '$domain_name' already exists (ID $DOMAIN_ID)"
  else
    echo ""
    echo "* Create domain '$domain_name'"

    API_URL="$API_BASE/sites/$SITE_ID/domains"

    JSON_PAYLOAD='{
      "name": "'"$domain_name"'",
      "allow_wildcard_subdomains": false,
      "www_redirect_type": "none"
    }'

    if [[ $DEBUG == 'true' ]]; then
      echo "[DEBUG] CURL POST on $API_URL with payload :"
      echo "$JSON_PAYLOAD"
      echo ""
    fi

    HTTP_STATUS=$(
      curl -s -o create-domain-response.json -w "%{http_code}" \
        -X POST \
        -H "$AUTH_HEADER" \
        -H "$ACCEPT_HEADER" \
        -H "$CONTENT_TYPE_HEADER" \
        -d "$JSON_PAYLOAD" \
        "$API_URL"
    )

    JSON_RESPONSE=$(cat create-domain-response.json)

    if [[ $HTTP_STATUS -eq 202 ]]; then
      DOMAIN_ID=$(jq -r '.data.id' create-domain-response.json)
      echo "Domain '$domain_name' created successfully (ID $DOMAIN_ID)"
    else
      echo "Failed to create domain '$domain_name'. HTTP status code: $HTTP_STATUS"
      echo "JSON Response:"
      echo "$JSON_RESPONSE"
      exit 1
    fi
  fi

  DOMAIN_IDS+=("$DOMAIN_ID")
done

if [[ $INPUT_LETSENCRYPT_CERTIFICATE == 'true' ]]; then
  for i in "${!DOMAIN_NAMES[@]}"; do
    domain_name="${DOMAIN_NAMES[$i]}"
    domain_id="${DOMAIN_IDS[$i]}"

    echo ""
    echo "* Check if domain '$domain_name' has a certificate"

    API_URL="$API_BASE/sites/$SITE_ID/domains/$domain_id/certificates"

    if [[ $DEBUG == 'true' ]]; then
      echo "[DEBUG] CURL GET on $API_URL"
      echo ""
    fi

    JSON_RESPONSE=$(
      curl -s -H "$AUTH_HEADER" \
        -H "$ACCEPT_HEADER" \
        "$API_URL"
    )
    echo "$JSON_RESPONSE" > "domain-$domain_id-certificates.json"

    if [[ $DEBUG == 'true' ]]; then
      echo "[DEBUG] response JSON:"
      echo "$JSON_RESPONSE"
      echo ""
    fi

    if jq -e '.data | length > 0' "domain-$domain_id-certificates.json" > /dev/null; then
      echo "Domain '$domain_name' already has at least one certificate"
      continue
    fi

    echo ""
    echo "* Obtain Let's Encrypt certificate for '$domain_name'"

    API_URL="$API_BASE/sites/$SITE_ID/domains/$domain_id/certificates"

    JSON_PAYLOAD='{
      "enable": true,
      "type": "letsencrypt",
      "letsencrypt": {
        "verification_method": "http-01",
        "key_type": "rsa"
      }
    }'

    if [[ $DEBUG == 'true' ]]; then
      echo "[DEBUG] CURL POST on $API_URL with payload :"
      echo "$JSON_PAYLOAD"
      echo ""
    fi

    HTTP_STATUS=$(
      curl -s -o "domain-$domain_id-certificate-create-response.json" -w "%{http_code}" \
        -X POST \
        -H "$AUTH_HEADER" \
        -H "$ACCEPT_HEADER" \
        -H "$CONTENT_TYPE_HEADER" \
        -d "$JSON_PAYLOAD" \
        "$API_URL"
    )

    JSON_RESPONSE=$(cat "domain-$domain_id-certificate-create-response.json")

    if [[ $HTTP_STATUS -eq 202 ]]; then
      CERTIFICATE_ID=$(jq -r '.data.id' "domain-$domain_id-certificate-create-response.json")
      echo "Request for a Let's Encrypt certificate sent successfully (ID $CERTIFICATE_ID)"
    else
      echo "Failed to request Let's Encrypt certificate for '$domain_name'. HTTP status code: $HTTP_STATUS"
      echo "JSON Response:"
      echo "$JSON_RESPONSE"
      exit 1
    fi

    echo ""
    echo "* Wait for certificate to be installed"

    API_URL="$API_BASE/sites/$SITE_ID/domains/$domain_id/certificates/$CERTIFICATE_ID"

    start_time=$(date +%s)
    elapsed_time=0
    status=""

    while [[ "$status" != "installed" && "$elapsed_time" -lt $INPUT_CERTIFICATE_SETUP_TIMEOUT ]]; do
      if [[ $DEBUG == 'true' ]]; then
        echo "[DEBUG] CURL GET on $API_URL"
        echo ""
      fi

      HTTP_STATUS=$(
        curl -s -o certificate-status-response.json -w "%{http_code}" \
        -H "$AUTH_HEADER" \
        -H "$ACCEPT_HEADER" \
        "$API_URL"
      )

      JSON_RESPONSE=$(cat certificate-status-response.json)

      if [[ $DEBUG == 'true' ]]; then
        echo "[DEBUG] response JSON:"
        echo "$JSON_RESPONSE"
        echo ""
      fi

      if [[ "$HTTP_STATUS" != "200" ]]; then
        echo "Response code $HTTP_STATUS, retrying in 5 seconds..."
        sleep 5
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        continue
      fi

      status=$(echo "$JSON_RESPONSE" | jq -r '.data.attributes.status')

      if [[ "$status" != "installed" ]]; then
        echo "Status is not \"installed\" ($status), retrying in 5 seconds..."
        sleep 5
      fi

      current_time=$(date +%s)
      elapsed_time=$((current_time - start_time))
    done

    if [[ "$status" != "installed" ]]; then
      echo "Timeout reached, exiting retry loop."
      exit 1
    else
      echo "Certificate installed successfully"
    fi
  done
fi

echo ""
echo "* Setup .env file"

cp "$WORKSPACE/$INPUT_ENV_STUB_PATH" .env

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] Stub .env file content:"
  cat .env
  echo ""
fi

sed -i -e "s#STUB_HOST#$INPUT_HOST#" .env
sed -i -e "s#STUB_DATABASE_NAME#$INPUT_DATABASE_NAME#" .env
sed -i -e "s#STUB_DATABASE_USER#$INPUT_DATABASE_USER#" .env
sed -i -e "s#STUB_DATABASE_PASSWORD#$INPUT_DATABASE_PASSWORD#" .env

ENV_CONTENT=$(cat .env)

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] Generated .env file content:"
  echo "$ENV_CONTENT"
  echo ""
fi

ESCAPED_ENV_CONTENT=$(echo "$ENV_CONTENT" | jq -Rsa .)

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] Escaped .env file content:"
  echo "$ESCAPED_ENV_CONTENT"
  echo ""
fi

API_URL="$API_BASE/sites/$SITE_ID/environment"

JSON_PAYLOAD='{
  "environment": '"$ESCAPED_ENV_CONTENT"'
}'

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] CURL PUT on $API_URL with payload :"
  echo "$JSON_PAYLOAD"
  echo ""
fi

HTTP_STATUS=$(
  curl -s -o update-site-env-response.json -w "%{http_code}" \
    -X PUT \
    -H "$AUTH_HEADER" \
    -H "$ACCEPT_HEADER" \
    -H "$CONTENT_TYPE_HEADER" \
    -d "$JSON_PAYLOAD" \
    "$API_URL"
)

JSON_RESPONSE=$(cat update-site-env-response.json)

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] response JSON:"
  echo "$JSON_RESPONSE"
  echo ""
fi

if [[ $HTTP_STATUS -eq 202 ]]; then
  echo ".env file updated successfully"
else
  echo "Failed to update .env file. HTTP status code: $HTTP_STATUS"
  echo "JSON Response:"
  echo "$JSON_RESPONSE"
  exit 1
fi

echo ""
echo "* Setup deploy script"

cp "$WORKSPACE/$INPUT_DEPLOY_SCRIPT_STUB_PATH" deploy-script

sed -i -e "s#STUB_HOST#$INPUT_HOST#" deploy-script

DEPLOY_SCRIPT_CONTENT=$(cat deploy-script)
ESCAPED_DEPLOY_SCRIPT_CONTENT=$(echo "$DEPLOY_SCRIPT_CONTENT" | jq -Rsa .)

API_URL="$API_BASE/sites/$SITE_ID/deployments/script"

JSON_PAYLOAD='{
  "content": '"$ESCAPED_DEPLOY_SCRIPT_CONTENT"',
  "auto_source": '$INPUT_DEPLOYMENT_AUTO_SOURCE'
}'

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] CURL PUT on $API_URL with payload :"
  echo "$JSON_PAYLOAD"
  echo ""
fi

HTTP_STATUS=$(
  curl -s -o update-site-deployment-script-response.json -w "%{http_code}" \
    -X PUT \
    -H "$AUTH_HEADER" \
    -H "$ACCEPT_HEADER" \
    -H "$CONTENT_TYPE_HEADER" \
    -d "$JSON_PAYLOAD" \
    "$API_URL"
)

JSON_RESPONSE=$(cat update-site-deployment-script-response.json)

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] response JSON:"
  echo "$JSON_RESPONSE"
  echo ""
fi

if [[ $HTTP_STATUS -eq 200 ]]; then
  echo "Deployment script updated successfully"
else
  echo "Failed to update deployment script. HTTP status code: $HTTP_STATUS"
  echo "JSON Response:"
  echo "$JSON_RESPONSE"
  exit 1
fi

echo ""
echo "* Launch deployment"

API_URL="$API_BASE/sites/$SITE_ID/deployments"

HTTP_STATUS=$(
  curl -s -o deploy-site-response.json -w "%{http_code}" \
    -X POST \
    -H "$AUTH_HEADER" \
    -H "$ACCEPT_HEADER" \
    "$API_URL"
)

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] CURL POST on $API_URL"
  echo ""
fi

JSON_RESPONSE=$(cat deploy-site-response.json)

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] response JSON:"
  echo "$JSON_RESPONSE"
  echo ""
fi

if [[ $HTTP_STATUS -eq 202 ]]; then
  echo "Deployment launched successfully"
else
  echo "Failed to launch deployment. HTTP status code: $HTTP_STATUS"
  echo "JSON Response:"
  echo "$JSON_RESPONSE"
  exit 1
fi

echo ""
echo "* Wait for deployment"

# /deployments/status only reflects a deployment currently in progress and
# reverts to null once it finishes (Forge API v2), so poll the deployments
# list (most recent first) and check its status instead.
API_URL="$API_BASE/sites/$SITE_ID/deployments?sort=-created_at&page%5Bsize%5D=1"

start_time=$(date +%s)
elapsed_time=0
status=""

while [[ "$status" != "finished" && "$status" != "failed" && "$status" != "failed-build" && "$status" != "cancelled" && "$elapsed_time" -lt $INPUT_DEPLOYMENT_TIMEOUT ]]; do
  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL GET on $API_URL"
    echo ""
  fi

  HTTP_STATUS=$(
    curl -s -o check-site-deployment-response.json -w "%{http_code}" \
    -H "$AUTH_HEADER" \
    -H "$ACCEPT_HEADER" \
    "$API_URL"
  )

  JSON_RESPONSE=$(cat check-site-deployment-response.json)

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] response JSON:"
    echo "$JSON_RESPONSE"
    echo ""
  fi

  if [[ "$HTTP_STATUS" != "200" ]]; then
    echo "Response code is not 200 but $HTTP_STATUS"
    echo "API Response:"
    echo "$JSON_RESPONSE"
    exit 1
  fi

  status=$(echo "$JSON_RESPONSE" | jq -r '.data[0].attributes.status')

  if [[ "$status" != "finished" && "$status" != "failed" && "$status" != "failed-build" && "$status" != "cancelled" ]]; then
    echo "Status is $status, retrying in 5 seconds..."
    sleep 5
  fi

  current_time=$(date +%s)
  elapsed_time=$((current_time - start_time))
done

if [[ "$status" != "finished" && "$status" != "failed" && "$status" != "failed-build" && "$status" != "cancelled" ]]; then
  echo "Timeout reached, exiting retry loop."
  exit 1
fi

echo ""
echo "* Get last deployment"

API_URL="$API_BASE/sites/$SITE_ID/deployments?sort=-created_at&page%5Bsize%5D=1"

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] CURL GET on $API_URL"
  echo ""
fi

HTTP_STATUS=$(
curl -s -o last-deployment-response.json -w "%{http_code}" \
  -H "$AUTH_HEADER" \
  -H "$ACCEPT_HEADER" \
  "$API_URL"
)

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] response JSON:"
  cat last-deployment-response.json
  echo ""
fi

if [[ $HTTP_STATUS -eq 200 ]]; then
  echo "Fetched last deployment successfully"
  jq -r '.data[0]' last-deployment-response.json > last-deployment.json
else
  echo "Failed to fetch last deployment. HTTP status code: $HTTP_STATUS"
  echo "JSON Response:"
  cat last-deployment-response.json
  exit 1
fi

echo ""
echo "* Get last deployment output"

LAST_DEPLOYMENT_DATA=$(cat last-deployment.json)
LAST_DEPLOYMENT_ID=$(echo "$LAST_DEPLOYMENT_DATA" | jq -r '.id')

API_URL="$API_BASE/sites/$SITE_ID/deployments/$LAST_DEPLOYMENT_ID/log"

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] CURL GET on $API_URL"
  echo ""
fi

HTTP_STATUS=$(
  curl -s -o deployment-log-response.json -w "%{http_code}" \
    -H "$AUTH_HEADER" \
    -H "$ACCEPT_HEADER" \
    "$API_URL"
)

JSON_RESPONSE=$(cat deployment-log-response.json)

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] response JSON:"
  echo "$JSON_RESPONSE"
  echo ""
fi

if [[ $HTTP_STATUS -eq 200 ]]; then
  echo "Fetched last deployment output successfully"
else
  echo "Failed to fetch last deployment output. HTTP status code: $HTTP_STATUS"
  echo "JSON Response:"
  echo "$JSON_RESPONSE"
  exit 1
fi

echo ""
echo "* Check last deployment"

LAST_DEPLOYMENT_STATUS=$(echo "$LAST_DEPLOYMENT_DATA" | jq -r '.attributes.status')
LAST_DEPLOYMENT_OUTPUT=$(cat deployment-log-response.json | jq -r '.data.attributes.output')

if [[ $LAST_DEPLOYMENT_STATUS == 'finished' ]]; then
  echo "Deployment finished successfully"
  echo ""
  echo "Deployment output:"
  echo ""
  echo "$LAST_DEPLOYMENT_OUTPUT"
else
  echo "Deployment failed ($LAST_DEPLOYMENT_STATUS)"
  echo ""
  echo "Deployment output:"
  echo ""
  echo "$LAST_DEPLOYMENT_OUTPUT"
  exit 1
fi

if [[ $INPUT_HORIZON_ENABLED == 'true' ]]; then
  echo ""
  echo "* Enable Laravel Horizon integration"

  API_URL="$API_BASE/sites/$SITE_ID/integrations/horizon"

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL POST on $API_URL"
    echo ""
  fi

  HTTP_STATUS=$(
    curl -s -o setup-site-horizon-response.json -w "%{http_code}" \
      -X POST \
      -H "$AUTH_HEADER" \
      -H "$ACCEPT_HEADER" \
      "$API_URL"
  )

  JSON_RESPONSE=$(cat setup-site-horizon-response.json)

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] response JSON:"
    echo "$JSON_RESPONSE"
    echo ""
  fi

  if [[ $HTTP_STATUS -eq 202 ]]; then
    echo "Laravel Horizon integration enabled successfully"
  else
    echo "Failed to enable Laravel Horizon integration. HTTP status code: $HTTP_STATUS"
    echo "JSON Response:"
    echo "$JSON_RESPONSE"
    exit 1
  fi
fi

if [[ $INPUT_SCHEDULER_ENABLED == 'true' ]]; then
  echo ""
  echo "* Enable Laravel Scheduler integration"

  API_URL="$API_BASE/sites/$SITE_ID/integrations/laravel-scheduler"

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL POST on $API_URL"
    echo ""
  fi

  HTTP_STATUS=$(
    curl -s -o setup-site-scheduler-response.json -w "%{http_code}" \
      -X POST \
      -H "$AUTH_HEADER" \
      -H "$ACCEPT_HEADER" \
      "$API_URL"
  )

  JSON_RESPONSE=$(cat setup-site-scheduler-response.json)

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] response JSON:"
    echo "$JSON_RESPONSE"
    echo ""
  fi

  if [[ $HTTP_STATUS -eq 202 ]]; then
    echo "Laravel Scheduler integration enabled successfully"
  else
    echo "Failed to enable Laravel Scheduler integration. HTTP status code: $HTTP_STATUS"
    echo "JSON Response:"
    echo "$JSON_RESPONSE"
    exit 1
  fi
fi

if [[ $INPUT_CREATE_WORKER == 'true' ]]; then
  echo ""
  echo '* Get Forge server background processes for this site'
  API_URL="$API_BASE/background-processes?filter%5Bsite_id%5D=$SITE_ID"

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL GET on $API_URL"
    echo ""
  fi

  JSON_RESPONSE=$(
    curl -s -H "$AUTH_HEADER" \
      -H "$ACCEPT_HEADER" \
      "$API_URL"
  )
  echo "$JSON_RESPONSE" > background-processes.json

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] response JSON:"
    echo "$JSON_RESPONSE"
    echo ""
  fi

  # Build the artisan command the worker should run (Forge API v2 replaced the
  # dedicated "queue worker" resource with a generic "background process" one).
  # Background processes always use the server's default CLI PHP version unless
  # the binary is explicit, so use the site's own PHP version (e.g. "php84" -> "php8.4").
  PHP_VERSION_DIGITS="${INPUT_PHP_VERSION#php}"
  PHP_BINARY="php${PHP_VERSION_DIGITS:0:1}.${PHP_VERSION_DIGITS:1:1}"

  WORKER_COMMAND="$PHP_BINARY artisan queue:work $INPUT_WORKER_CONNECTION --sleep=$INPUT_WORKER_SLEEP --timeout=$INPUT_WORKER_TIMEOUT"

  if [[ -n "$INPUT_WORKER_TRIES" ]]; then
    WORKER_COMMAND="$WORKER_COMMAND --tries=$INPUT_WORKER_TRIES"
  fi

  if [[ -n "$INPUT_WORKER_QUEUE" ]]; then
    WORKER_COMMAND="$WORKER_COMMAND --queue=$INPUT_WORKER_QUEUE"
  fi

  if [[ "$INPUT_WORKER_FORCE" == "true" ]]; then
    WORKER_COMMAND="$WORKER_COMMAND --force"
  fi

  WORKER_EXISTS=$(jq -r '(.data | length) > 0' background-processes.json)

  if [[ $WORKER_EXISTS == 'true' ]]; then
    echo "Background process found"
    echo ""
    echo "* Checking review-app worker configuration"
    echo ""

    FIRST_WORKER_DATA=$(jq -r '.data[0]' background-processes.json)
    echo "$FIRST_WORKER_DATA" > first_worker.json
    WORKER_ID=$(jq -r '.id' first_worker.json)

    if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
      echo "worker_id=$WORKER_ID" >> $GITHUB_OUTPUT
    fi

    if [[ $DEBUG == 'true' ]]; then
      echo "[DEBUG] first worker DATA JSON:"
      echo "$FIRST_WORKER_DATA"
      echo ""
    fi

    echo "Checking worker (ID $WORKER_ID)"

    WORKER_EXISTING_COMMAND=$(jq -r '.attributes.command' first_worker.json)
    WORKER_PROCESSES=$(jq -r '.attributes.processes' first_worker.json)

    NEED_WORKER_RECREATE='false'

    if [[ "$WORKER_COMMAND" != "$WORKER_EXISTING_COMMAND" ]]; then
      echo "Existing worker command '$WORKER_EXISTING_COMMAND' is different than the requested '$WORKER_COMMAND' value"
      NEED_WORKER_RECREATE='true'
    fi

    if [[ "$INPUT_WORKER_PROCESSES" != "$WORKER_PROCESSES" ]]; then
      echo "Existing worker processes '$WORKER_PROCESSES' is different than the requested '$INPUT_WORKER_PROCESSES' value"
      NEED_WORKER_RECREATE='true'
    fi

    if [[ $NEED_WORKER_RECREATE == 'true' ]]; then
      echo ""
      echo "* Delete existing review-app worker"

      API_URL="$API_BASE/background-processes/$WORKER_ID"

      if [[ $DEBUG == 'true' ]]; then
        echo "[DEBUG] CURL DELETE on $API_URL"
        echo ""
      fi

      HTTP_STATUS=$(
        curl -s -o delete-existing-site-worker-response.json -w "%{http_code}" \
          -X DELETE \
          -H "$AUTH_HEADER" \
          -H "$ACCEPT_HEADER" \
          "$API_URL"
      )

      JSON_RESPONSE=$(cat delete-existing-site-worker-response.json)

      if [[ $HTTP_STATUS -eq 202 ]]; then
        echo "Worker (ID $WORKER_ID) deleted successfully"
        WORKER_EXISTS='false'
      else
        echo "Failed to delete worker (ID $WORKER_ID). HTTP status code: $HTTP_STATUS"
        echo "JSON Response:"
        echo "$JSON_RESPONSE"
        exit 1
      fi
    fi
  fi

  if [[ $WORKER_EXISTS == 'false' ]]; then
    echo ""
    echo "* Create review-app worker"

    API_URL="$API_BASE/background-processes"

    ESCAPED_WORKER_COMMAND=$(echo "$WORKER_COMMAND" | jq -Rsa .)
    SITE_ROOT_DIRECTORY=$(jq -r '.attributes.root_directory' site.json)
    # Background processes are server-scoped and require a unique "name" across
    # the whole server, so a hardcoded "Queue Worker" collides as soon as another
    # site (or a legacy v1 worker) on the same server already uses that name.
    # Strip the root domain (shared by every review-app site) to keep the name short.
    if [[ -n "$INPUT_ROOT_DOMAIN" ]]; then
      WORKER_NAME="Queue Worker ${INPUT_HOST%.$INPUT_ROOT_DOMAIN}"
    else
      WORKER_NAME="Queue Worker $INPUT_HOST"
    fi
    ESCAPED_WORKER_NAME=$(echo "$WORKER_NAME" | jq -Rsa .)

    JSON_PAYLOAD='{
      "name": '"$ESCAPED_WORKER_NAME"',
      "site_id": '"$SITE_ID"',
      "directory": "'"$SITE_ROOT_DIRECTORY"'",
      "command": '"$ESCAPED_WORKER_COMMAND"',
      "user": "forge",
      "processes": '"$INPUT_WORKER_PROCESSES"',
      "stopwaitsecs": '"$INPUT_WORKER_STOPWAITSECS"'
    }'

    if [[ $DEBUG == 'true' ]]; then
      echo "[DEBUG] CURL POST on $API_URL with payload :"
      echo "$JSON_PAYLOAD"
      echo ""
    fi

    HTTP_STATUS=$(
      curl -s -o create-site-worker-response.json -w "%{http_code}" \
        -X POST \
        -H "$AUTH_HEADER" \
        -H "$ACCEPT_HEADER" \
        -H "$CONTENT_TYPE_HEADER" \
        -d "$JSON_PAYLOAD" \
        "$API_URL"
    )

    JSON_RESPONSE=$(cat create-site-worker-response.json)
    if [[ $HTTP_STATUS -eq 202 ]]; then
      if [[ $DEBUG == 'true' ]]; then
        echo "[DEBUG] response JSON:"
        echo "$JSON_RESPONSE"
        echo ""
      fi
      WORKER_ID=$(jq -r '.data.id' create-site-worker-response.json)

      if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
        echo "worker_id=$WORKER_ID" >> $GITHUB_OUTPUT
      fi

      echo "Worker (ID $WORKER_ID) created successfully"
    else
      echo "Failed to create worker. HTTP status code: $HTTP_STATUS"
      echo "JSON Response:"
      echo "$JSON_RESPONSE"
      exit 1
    fi
  fi
fi

if [[ $INPUT_SECURITY_RULE_ENABLED == 'true' ]]; then
  echo ""
  echo '* Get Forge server site security rules'
  API_URL="$API_BASE/sites/$SITE_ID/security-rules"

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL GET on $API_URL"
    echo ""
  fi

  JSON_RESPONSE=$(
    curl -s -H "$AUTH_HEADER" \
      -H "$ACCEPT_HEADER" \
      "$API_URL"
  )
  echo "$JSON_RESPONSE" > security-rules.json

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] response JSON:"
    echo "$JSON_RESPONSE"
    echo ""
  fi

  # Check if security rule exists
  SECURITY_RULE_EXISTS=$(jq -r '(.data | length) > 0' security-rules.json)

  if [[ $SECURITY_RULE_EXISTS == 'false' ]]; then
    echo "Security rule not found"
  fi

  if [[ $SECURITY_RULE_EXISTS == 'true' ]]; then
    echo "Security rule found"
    echo ""
    echo "* Delete existing security rule"

    FIRST_SECURITY_RULE_DATA=$(jq -r '.data[0]' security-rules.json)

    echo "$FIRST_SECURITY_RULE_DATA" > first_security_rule.json
    SECURITY_RULE_ID=$(jq -r '.id' first_security_rule.json)

    API_URL="$API_BASE/sites/$SITE_ID/security-rules/$SECURITY_RULE_ID"

    if [[ $DEBUG == 'true' ]]; then
      echo "[DEBUG] CURL DELETE on $API_URL"
      echo ""
    fi

    HTTP_STATUS=$(
      curl -s -o delete-existing-site-security-rule-response.json -w "%{http_code}" \
        -X DELETE \
        -H "$AUTH_HEADER" \
        -H "$ACCEPT_HEADER" \
        "$API_URL"
    )

    JSON_RESPONSE=$(cat delete-existing-site-security-rule-response.json)

    if [[ $HTTP_STATUS -eq 202 ]]; then
      echo "Security rule (ID $SECURITY_RULE_ID) deleted successfully"
      SECURITY_RULE_EXISTS='false'
    else
      echo "Failed to delete security rule (ID $SECURITY_RULE_ID). HTTP status code: $HTTP_STATUS"
      echo "JSON Response:"
      echo "$JSON_RESPONSE"
      exit 1
    fi
  fi

  if [[ $SECURITY_RULE_EXISTS == 'false' ]]; then
    echo ""
    echo "* Create review-app security rule"

    API_URL="$API_BASE/sites/$SITE_ID/security-rules"

    JSON_PAYLOAD='{
      "name": "Access Restricted",
      "credentials": [
        {
          "username": "'"$INPUT_SECURITY_RULE_USERNAME"'",
          "password": "'"$INPUT_SECURITY_RULE_PASSWORD"'"
        }
      ]
    }'

    if [[ $DEBUG == 'true' ]]; then
      echo "[DEBUG] CURL POST on $API_URL with payload :"
      echo "$JSON_PAYLOAD"
      echo ""
    fi

    HTTP_STATUS=$(
      curl -s -o create-site-security-rule-response.json -w "%{http_code}" \
        -X POST \
        -H "$AUTH_HEADER" \
        -H "$ACCEPT_HEADER" \
        -H "$CONTENT_TYPE_HEADER" \
        -d "$JSON_PAYLOAD" \
        "$API_URL"
    )

    JSON_RESPONSE=$(cat create-site-security-rule-response.json)
    if [[ $HTTP_STATUS -eq 202 ]]; then
      if [[ $DEBUG == 'true' ]]; then
        echo "[DEBUG] response JSON:"
        echo "$JSON_RESPONSE"
        echo ""
      fi
      SECURITY_RULE_ID=$(jq -r '.data.id' create-site-security-rule-response.json)
      echo "Security rule (ID $SECURITY_RULE_ID) created successfully"
    else
      echo "Failed to create security rule. HTTP status code: $HTTP_STATUS"
      echo "JSON Response:"
      echo "$JSON_RESPONSE"
      exit 1
    fi
  fi
fi
