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

if [[ -z "$INPUT_FULL_DOMAIN" ]]; then
  INPUT_FULL_DOMAIN=$(echo "$INPUT_HOST" | sed "s/^$INPUT_FQDN_PREFIX//")
fi

if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
  echo "host=$INPUT_HOST" >> $GITHUB_OUTPUT
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

if [[ -z "$INPUT_PROJECT_TYPE" ]]; then
  INPUT_PROJECT_TYPE='php'
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

if [[ -z "$INPUT_WORKER_PHP_VERSION" ]]; then
  INPUT_WORKER_PHP_VERSION=$INPUT_PHP_VERSION
fi

if [[ -z "$INPUT_WORKER_DAEMON" ]]; then
  INPUT_WORKER_DAEMON='true'
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
API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites"

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] CURL GET on $API_URL"
  echo ""
fi

JSON_RESPONSE=$(
  curl -s -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    "$API_URL"
)

echo "$JSON_RESPONSE" > sites.json

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] response JSON:"
  echo "$JSON_RESPONSE"
  echo ""
fi

# Check if review-app site exists
SITE_DATA=$(jq -r '.sites[] | select(.name == "'"$INPUT_HOST"'") // empty' sites.json)
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
  echo ""
  echo "* Create review-app site"

  API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites"

  if [[ $INPUT_CREATE_DATABASE == 'true' ]]; then
    if [[ -z "$INPUT_NGINX_TEMPLATE" ]]; then
      JSON_PAYLOAD='{
        "domain": "'"$INPUT_HOST"'",
        "project_type": "'"$INPUT_PROJECT_TYPE"'",
        "directory": "'"$INPUT_DIRECTORY"'",
        "isolated": '"$INPUT_ISOLATED"',
        "php_version": "'"$INPUT_PHP_VERSION"'",
        "database": "'"$INPUT_DATABASE_NAME"'"
      }'
    else
      JSON_PAYLOAD='{
        "domain": "'"$INPUT_HOST"'",
        "project_type": "'"$INPUT_PROJECT_TYPE"'",
        "directory": "'"$INPUT_DIRECTORY"'",
        "isolated": '"$INPUT_ISOLATED"',
        "php_version": "'"$INPUT_PHP_VERSION"'",
        "database": "'"$INPUT_DATABASE_NAME"'",
        "nginx_template": "'"$INPUT_NGINX_TEMPLATE"'"
      }'
    fi
  else
    if [[ -z "$INPUT_NGINX_TEMPLATE" ]]; then
      JSON_PAYLOAD='{
        "domain": "'"$INPUT_HOST"'",
        "project_type": "'"$INPUT_PROJECT_TYPE"'",
        "directory": "'"$INPUT_DIRECTORY"'",
        "isolated": '"$INPUT_ISOLATED"',
        "php_version": "'"$INPUT_PHP_VERSION"'"
      }'
    else
      JSON_PAYLOAD='{
        "domain": "'"$INPUT_HOST"'",
        "project_type": "'"$INPUT_PROJECT_TYPE"'",
        "directory": "'"$INPUT_DIRECTORY"'",
        "isolated": '"$INPUT_ISOLATED"',
        "php_version": "'"$INPUT_PHP_VERSION"'",
        "nginx_template": "'"$INPUT_NGINX_TEMPLATE"'"
      }'
    fi
  fi

  if [[ -n "$INPUT_ALIASES" ]]; then
    if ! echo "$INPUT_ALIASES" | jq empty; then
      echo "Invalid JSON format for aliases: $INPUT_ALIASES"
      exit 1
    fi

    if ! echo "$INPUT_ALIASES" | jq -e 'if type == "array" then . else empty end' > /dev/null; then
      echo "Aliases should be a JSON array: $INPUT_ALIASES"
      exit 1
    fi

    if [[ -n "$INPUT_ALIASES" ]]; then
      JSON_PAYLOAD=$(echo "$JSON_PAYLOAD" | jq --argjson aliases "$INPUT_ALIASES" '. + {aliases: $aliases}')
    fi
  fi

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL POST on $API_URL with payload :"
    echo "$JSON_PAYLOAD"
    echo ""
  fi

  HTTP_STATUS=$(
    curl -s -o site-create-response.json -w "%{http_code}" \
      -X POST \
      -H "$AUTH_HEADER" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -d "$JSON_PAYLOAD" \
      "$API_URL"
  )

  JSON_RESPONSE=$(cat site-create-response.json)

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] response JSON:"
    echo "$JSON_RESPONSE"
    echo ""
  fi

  if [[ $HTTP_STATUS -eq 200 ]]; then
    jq '.site' site-create-response.json > site.json
    SITE_ID=$(jq -r '.id' site.json)

    if [[ -n "$GITHUB_ACTIONS" && "$GITHUB_ACTIONS" == "true" ]]; then
      echo "site_id=$SITE_ID" >> $GITHUB_OUTPUT
    fi

    if [[ $INPUT_CREATE_DATABASE == 'true' ]]; then
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
fi

if [[ $INPUT_CONFIGURE_REPOSITORY == 'true' ]]; then
  echo ""
  echo "* Check if repository is configured"
  SITE_REPOSITORY=$(jq -r '.repository' site.json)

  if [[ $SITE_REPOSITORY == 'null' ]]; then
    echo "Repository not configured on Forge site"
    REPOSITORY_CONFIGURED='false'
  else
    echo "Repository configured on Forge site ($SITE_REPOSITORY)"
    REPOSITORY_CONFIGURED='true'
  fi

  if [[ $REPOSITORY_CONFIGURED == 'false' ]]; then
    echo ""
    echo "* Setup git repository on site"

    API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID/git"

    JSON_PAYLOAD='{
      "provider": "'"$INPUT_REPOSITORY_PROVIDER"'",
      "repository": "'"$INPUT_REPOSITORY"'",
      "branch": "'"$INPUT_BRANCH"'",
      "composer": '"$INPUT_COMPOSER"'
    }'

    if [[ $DEBUG == 'true' ]]; then
        echo "[DEBUG] CURL POST on $API_URL with payload :"
        echo "$JSON_PAYLOAD"
        echo ""
      fi

    HTTP_STATUS=$(
      curl -s -o setup-git-response.json -w "%{http_code}" \
        -X POST \
        -H "$AUTH_HEADER" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -d "$JSON_PAYLOAD" \
        "$API_URL"
    )

    JSON_RESPONSE=$(cat setup-git-response.json)

    if [[ $DEBUG == 'true' ]]; then
      echo "[DEBUG] response JSON:"
      echo "$JSON_RESPONSE"
      echo ""
    fi

    if [[ $HTTP_STATUS -eq 200 ]]; then
      echo "Git repository configured successfully"
    else
      echo "Failed to setup git repository on Forge site. HTTP status code: $HTTP_STATUS"
      echo "JSON Response:"
      echo "$JSON_RESPONSE"
      exit 1
    fi
  fi
fi

if [[ $INPUT_LETSENCRYPT_CERTIFICATE == 'true' ]]; then
  echo ""
  echo "* Check if site has a certificate"

  API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID/certificates"

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL GET on $API_URL"
    echo ""
  fi

  HTTP_STATUS=$(
    curl -s -o site-certificates-response.json -w "%{http_code}" \
    -X GET \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "$API_URL"
  )

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] response JSON:"
    cat site-certificates-response.json
    echo ""
  fi

  if [[ $HTTP_STATUS -eq 200 ]]; then
    echo "Fetched site certificates successfully"
    if jq -e '.certificates | length > 0' site-certificates-response.json > /dev/null; then
      echo "Site has at least one certificate"
      CERTIFICATE_FOUND='true'
    else
      echo "Site has no certificate"
      CERTIFICATE_FOUND='false'
    fi
  else
    echo "Failed to fetch site certificates. HTTP status code: $HTTP_STATUS"
    echo "JSON Response:"
    cat site-certificates-response.json
    exit 1
  fi

  if [[ $CERTIFICATE_FOUND == 'false' ]]; then
    echo ""
    echo "* Obtain Let's Encrypt certificate"

    API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID/certificates/letsencrypt"

    JSON_PAYLOAD='{
      "domains": ["'"$INPUT_HOST"'"]
    }'

    if [[ $DEBUG == 'true' ]]; then
      echo "[DEBUG] CURL POST on $API_URL with payload :"
      echo "$JSON_PAYLOAD"
      echo ""
    fi

    HTTP_STATUS=$(
      curl -s -o site-letsencrypt-response.json -w "%{http_code}" \
        -X POST \
        -H "$AUTH_HEADER" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -d "$JSON_PAYLOAD" \
        "$API_URL"
    )

    JSON_RESPONSE=$(cat site-letsencrypt-response.json)

    if [[ $DEBUG == 'true' ]]; then
      echo "[DEBUG] response JSON:"
      echo "$JSON_RESPONSE"
      echo ""
    fi

    if [[ $HTTP_STATUS -eq 200 ]]; then
      echo "Request for a let's encrypt certificate sent successfully"
      jq -r '.certificate' site-letsencrypt-response.json > certificate.json
    else
      echo "Failed to request let's encrypt certificate. HTTP status code: $HTTP_STATUS"
      echo "JSON Response:"
      echo "$JSON_RESPONSE"
      exit 1
    fi

    echo ""
    echo "* Wait for certificate to be installed"

    CERTIFICATE_DATA=$(cat certificate.json)
    CERTIFICATE_ID=$(echo "$CERTIFICATE_DATA" | jq -r '.id')

    API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID/certificates/$CERTIFICATE_ID"

    start_time=$(date +%s)
    elapsed_time=0
    status=""

    while [[ "$status" != "installed" && "$elapsed_time" -lt $INPUT_CERTIFICATE_SETUP_TIMEOUT ]]; do
      if [[ $DEBUG == 'true' ]]; then
        echo "[DEBUG] CURL GET on $API_URL "
        echo ""
      fi

      HTTP_STATUS=$(
        curl -s -o sites-certificates-response.json -w "%{http_code}" \
        -X GET \
        -H "$AUTH_HEADER" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        "$API_URL"
      )

      JSON_RESPONSE=$(cat sites-certificates-response.json)

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

      status=$(echo "$JSON_RESPONSE" | jq -r '.certificate."status"')

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
  fi
fi

echo ""
echo "* Setup .env file"

cp "$WORKSPACE/$INPUT_ENV_STUB_PATH" .env

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] Stub .env file content:"
  cat .env
  echo ""
fi

sed -i -e "s#STUB_FULL_DOMAIN#$INPUT_FULL_DOMAIN#" .env
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

API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID/env"

JSON_PAYLOAD='{
  "content": '"$ESCAPED_ENV_CONTENT"'
}'

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] CURL POST on $API_URL with payload :"
  echo "$JSON_PAYLOAD"
  echo ""
fi

HTTP_STATUS=$(
  curl -s -o update-site-env-response.json -w "%{http_code}" \
    -X PUT \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" \
    "$API_URL"
)

JSON_RESPONSE=$(cat update-site-env-response.json)

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] response JSON:"
  echo "$JSON_RESPONSE"
  echo ""
fi

if [[ $HTTP_STATUS -eq 200 ]]; then
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

API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID/deployment/script"

JSON_PAYLOAD='{
  "content": '"$ESCAPED_DEPLOY_SCRIPT_CONTENT"',
  "auto_source": '$INPUT_DEPLOYMENT_AUTO_SOURCE'
}'

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] CURL POST on $API_URL with payload :"
  echo "$JSON_PAYLOAD"
  echo ""
fi

HTTP_STATUS=$(
  curl -s -o update-site-deployment-script-response.json -w "%{http_code}" \
    -X PUT \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
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
  echo "Failed to update .env file. HTTP status code: $HTTP_STATUS"
  echo "JSON Response:"
  echo "$JSON_RESPONSE"
  exit 1
fi

echo ""
echo "* Launch deployment"

API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID/deployment/deploy"

HTTP_STATUS=$(
  curl -s -o deploy-site-response.json -w "%{http_code}" \
    -X POST \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
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

if [[ $HTTP_STATUS -eq 200 ]]; then
  echo "Deployment launched successfully"
else
  echo "Failed to launch deployment. HTTP status code: $HTTP_STATUS"
  echo "JSON Response:"
  echo "$JSON_RESPONSE"
  exit 1
fi

echo ""
echo "* Wait for deployment"

API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID"

start_time=$(date +%s)
elapsed_time=0
status=""

while [[ "$status" != "null" && "$elapsed_time" -lt $INPUT_DEPLOYMENT_TIMEOUT ]]; do
  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL GET on $API_URL"
    echo ""
  fi

  HTTP_STATUS=$(
    curl -s -o check-site-deployment-response.json -w "%{http_code}" \
    -X GET \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
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

  status=$(echo "$JSON_RESPONSE" | jq -r '.site."deployment_status"')

  if [[ "$status" != "null" ]]; then
    echo "Status is not null ($status), retrying in 5 seconds..."
    sleep 5
  fi

  current_time=$(date +%s)
  elapsed_time=$((current_time - start_time))
done

if [[ "$status" != "null" ]]; then
  echo "Timeout reached, exiting retry loop."
  exit 1
fi

echo ""
echo "* Get last deployment"

API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID/deployment-history"

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] CURL GET on $API_URL"
  echo ""
fi

HTTP_STATUS=$(
curl -s -o last-deployment-response.json -w "%{http_code}" \
  -X GET \
  -H "$AUTH_HEADER" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "$API_URL"
)

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] response JSON:"
  cat last-deployment-response.json
  echo ""
fi

if [[ $HTTP_STATUS -eq 200 ]]; then
  echo "Fetched last deployment successfully "
  jq -r '.deployments[0]' last-deployment-response.json > last-deployment.json
else
  echo "Failed to launch deployment. HTTP status code: $HTTP_STATUS"
  echo "JSON Response:"
  cat last-deployment-response.json
  exit 1
fi

echo ""
echo "* Get last deployment output"

LAST_DEPLOYMENT_DATA=$(cat last-deployment.json)
LAST_DEPLOYMENT_ID=$(echo "$LAST_DEPLOYMENT_DATA" | jq '.id')

API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID/deployment-history/$LAST_DEPLOYMENT_ID/output"

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] CURL GET on $API_URL"
  echo ""
fi

HTTP_STATUS=$(
  curl -s -o deployment-history-output-response.json -w "%{http_code}" \
    -X GET \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "$API_URL"
)

JSON_RESPONSE=$(cat deployment-history-output-response.json)

if [[ $DEBUG == 'true' ]]; then
  echo "[DEBUG] response JSON:"
  echo "$JSON_RESPONSE"
  echo ""
fi

if [[ $HTTP_STATUS -eq 200 ]]; then
  echo "Fetched last deployment output successfully "
  echo "$JSON_RESPONSE" > last-deployment-output-response.json
else
  echo "Failed to launch deployment. HTTP status code: $HTTP_STATUS"
  echo "JSON Response:"
  echo "$JSON_RESPONSE"
  exit 1
fi

echo ""
echo "* Check last deployment"

LAST_DEPLOYMENT_DATA=$(cat last-deployment.json)
LAST_DEPLOYMENT_STATUS=$(echo "$LAST_DEPLOYMENT_DATA" | jq -r '.status')
LAST_DEPLOYMENT_ID=$(echo "$LAST_DEPLOYMENT_DATA" | jq '.id')
LAST_DEPLOYMENT_OUTPUT_DATA=$(cat last-deployment-output-response.json)
LAST_DEPLOYMENT_OUTPUT=$(echo "$LAST_DEPLOYMENT_OUTPUT_DATA" | jq -r '.output')

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

  API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID/integrations/horizon"

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL POST on $API_URL"
    echo ""
  fi

  HTTP_STATUS=$(
    curl -s -o setup-site-horizon-response.json -w "%{http_code}" \
      -X POST \
      -H "$AUTH_HEADER" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      "$API_URL"
  )

  JSON_RESPONSE=$(cat setup-site-horizon-response.json)

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] response JSON:"
    echo "$JSON_RESPONSE"
    echo ""
  fi

  if [[ $HTTP_STATUS -eq 200 ]]; then
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

  API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID/integrations/laravel-scheduler"

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL POST on $API_URL"
    echo ""
  fi

  HTTP_STATUS=$(
    curl -s -o setup-site-scheduler-response.json -w "%{http_code}" \
      -X POST \
      -H "$AUTH_HEADER" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      "$API_URL"
  )

  JSON_RESPONSE=$(cat setup-site-scheduler-response.json)

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] response JSON:"
    echo "$JSON_RESPONSE"
    echo ""
  fi

  if [[ $HTTP_STATUS -eq 200 ]]; then
    echo "Laravel Scheduler integration enabled successfully"
  else
    echo "Failed to enable Laravel Scheduler integration. HTTP status code: $HTTP_STATUS"
    echo "JSON Response:"
    echo "$JSON_RESPONSE"
    exit 1
  fi
fi

if [[ $INPUT_QUICK_DEPLOY_ENABLED == 'true' ]]; then
  echo ""
  echo "* Enable quick deployment"

  API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID/deployment"

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL POST on $API_URL"
    echo ""
  fi

  HTTP_STATUS=$(
    curl -s -o setup-site-quick-deploy-response.json -w "%{http_code}" \
      -X POST \
      -H "$AUTH_HEADER" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      "$API_URL"
  )

  JSON_RESPONSE=$(cat setup-site-quick-deploy-response.json)

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] response JSON:"
    echo "$JSON_RESPONSE"
    echo ""
  fi

  if [[ $HTTP_STATUS -eq 200 ]]; then
    echo "Enable quick deployment successfully"
  else
    echo "Failed to enable quick deployment. HTTP status code: $HTTP_STATUS"
    echo "JSON Response:"
    echo "$JSON_RESPONSE"
    exit 1
  fi
fi

if [[ $INPUT_CREATE_WORKER == 'true' ]]; then
  echo ""
  echo '* Get Forge server site workers'
  API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID/workers"

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] CURL GET on $API_URL"
    echo ""
  fi

  JSON_RESPONSE=$(
    curl -s -H "$AUTH_HEADER" \
      -H "Accept: application/json" \
      "$API_URL"
  )
  echo "$JSON_RESPONSE" > workers.json

  if [[ $DEBUG == 'true' ]]; then
    echo "[DEBUG] response JSON:"
    echo "$JSON_RESPONSE"
    echo ""
  fi

  # Check if worker exists
  WORKER_EXISTS=$(jq -r '(.workers | length) > 0' workers.json)

  if [[ $WORKER_EXISTS == 'false' ]]; then
    echo "Worker not found"
  fi

  if [[ $WORKER_EXISTS == 'true' ]]; then
    echo "Worker found"
    echo ""
    echo "* Checking review-app worker configuration"
    echo ""

    FIRST_WORKER_DATA=$(jq -r '.workers[0]' workers.json)

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
    echo "⚠️ PHP version is not checked, in case of update, delete and recreate the review app manually."

    WORKER_CONNECTION_ID=$(jq -r '.connection' first_worker.json)
    WORKER_TIMEOUT=$(jq -r '.timeout' first_worker.json)
    WORKER_SLEEP=$(jq -r '.sleep' first_worker.json)
    WORKER_PROCESSES=$(jq -r '.processes' first_worker.json)
    WORKER_STOPWAITSECS=$(jq -r '.stopwaitsecs' first_worker.json)
    WORKER_DAEMON=$(jq -r '.daemon' first_worker.json)
    WORKER_TRIES=$(jq -r '.tries' first_worker.json)

    if [[ "$WORKER_DAEMON" == "1" ]]; then
      WORKER_DAEMON='true'
    else
      WORKER_DAEMON='false'
    fi

    WORKER_FORCE=$(jq -r '.force' first_worker.json)

    if [[ "$WORKER_FORCE" == "1" ]]; then
      WORKER_FORCE='true'
    else
      WORKER_FORCE='false'
    fi

    NEED_WORKER_RECREATE='false'

    if [[ "$INPUT_WORKER_CONNECTION" != "$WORKER_CONNECTION_ID" ]]; then
      echo "Existing worker connection '$WORKER_CONNECTION_ID' is different than the requested '$INPUT_WORKER_CONNECTION' value"
      NEED_WORKER_RECREATE='true'
    fi

    if [[ "$INPUT_WORKER_TIMEOUT" != "$WORKER_TIMEOUT" ]]; then
      echo "Existing worker timeout '$WORKER_TIMEOUT' is different than the requested '$INPUT_WORKER_TIMEOUT' value"
      NEED_WORKER_RECREATE='true'
    fi

    if [[ "$INPUT_WORKER_PROCESSES" != "$WORKER_PROCESSES" ]]; then
      echo "Existing worker processes '$WORKER_PROCESSES' is different than the requested '$INPUT_WORKER_PROCESSES' value"
      NEED_WORKER_RECREATE='true'
    fi

    if [[ "$INPUT_WORKER_STOPWAITSECS" != "$WORKER_STOPWAITSECS" ]]; then
      echo "Existing worker stopwaitsecs '$WORKER_STOPWAITSECS' is different than the requested '$INPUT_WORKER_STOPWAITSECS' value"
      NEED_WORKER_RECREATE='true'
    fi

    if [[ "$INPUT_WORKER_DAEMON" != "$WORKER_DAEMON" ]]; then
      echo "Existing worker daemon '$WORKER_DAEMON' is different than the requested '$INPUT_WORKER_DAEMON' value"
      NEED_WORKER_RECREATE='true'
    fi

    if [[ "$INPUT_WORKER_FORCE" != "$WORKER_FORCE" ]]; then
      echo "Existing worker force '$WORKER_FORCE' is different than the requested '$INPUT_WORKER_FORCE' value"
      NEED_WORKER_RECREATE='true'
    fi

    if [[ -z "$INPUT_WORKER_TRIES" ]]; then
      if [[ "null" != "$WORKER_TRIES" ]]; then
        echo "Existing worker tries '$WORKER_TRIES' is different than the requested 'null' value"
        NEED_WORKER_RECREATE='true'
      fi
    else
      if [[ "$INPUT_WORKER_TRIES" != "$WORKER_TRIES" ]]; then
        echo "Existing worker tries '$WORKER_TRIES' is different than the requested '$INPUT_WORKER_TRIES' value"
        NEED_WORKER_RECREATE='true'
      fi
    fi

    if [[ $NEED_WORKER_RECREATE == 'true' ]]; then
      echo ""
      echo "* Delete existing review-app worker"

      API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID/workers/$WORKER_ID"

      if [[ $DEBUG == 'true' ]]; then
        echo "[DEBUG] CURL DELETE on $API_URL"
        echo ""
      fi

      HTTP_STATUS=$(
        curl -s -o delete-existing-site-worker-response.json -w "%{http_code}" \
          -X DELETE \
          -H "$AUTH_HEADER" \
          -H "Accept: application/json" \
          -H "Content-Type: application/json" \
          "$API_URL"
      )

      JSON_RESPONSE=$(cat delete-existing-site-worker-response.json)

      if [[ $HTTP_STATUS -eq 200 ]]; then
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

    API_URL="https://forge.laravel.com/api/v1/servers/$INPUT_FORGE_SERVER_ID/sites/$SITE_ID/workers"

    JSON_PAYLOAD='{'

    if [[ -n "$INPUT_WORKER_TRIES" ]]; then
      JSON_PAYLOAD=$JSON_PAYLOAD'
        "tries": '$INPUT_WORKER_TRIES','
    fi

    if [[ -n "$INPUT_WORKER_PHP_VERSION" ]]; then
      JSON_PAYLOAD=$JSON_PAYLOAD'
        "php_version": "'$INPUT_WORKER_PHP_VERSION'",'
    fi

    if [[ -n "$INPUT_WORKER_QUEUE" ]]; then
      JSON_PAYLOAD=$JSON_PAYLOAD'
        "queue": "'$INPUT_WORKER_QUEUE'",'
    fi

    JSON_PAYLOAD=$JSON_PAYLOAD'
      "connection": "'"$INPUT_WORKER_CONNECTION"'",
      "timeout": '$INPUT_WORKER_TIMEOUT',
      "sleep": '$INPUT_WORKER_SLEEP',
      "processes": '$INPUT_WORKER_PROCESSES',
      "stopwaitsecs": '$INPUT_WORKER_STOPWAITSECS',
      "daemon": '$INPUT_WORKER_DAEMON',
      "force": '$INPUT_WORKER_FORCE'
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
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -d "$JSON_PAYLOAD" \
        "$API_URL"
    )

    JSON_RESPONSE=$(cat create-site-worker-response.json)
    if [[ $HTTP_STATUS -eq 200 ]]; then
      if [[ $DEBUG == 'true' ]]; then
        echo "[DEBUG] response JSON:"
        echo "$JSON_RESPONSE"
        echo ""
      fi
      WORKER_ID=$(jq -r '.worker.id' create-site-worker-response.json)
      echo "Worker (ID $WORKER_ID) created successfully"
    else
      echo "Failed to create worker. HTTP status code: $HTTP_STATUS"
      echo "JSON Response:"
      echo "$JSON_RESPONSE"
      exit 1
    fi
  fi
fi