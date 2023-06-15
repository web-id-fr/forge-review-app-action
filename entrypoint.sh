#!/bin/sh
set -e

# Prepare vars

if [[ -z "$BRANCH" ]]; then
  BRANCH=$GITHUB_HEAD_REF
fi

ESCAPED_BRANCH=$(echo "$BRANCH" | sed -e 's/[^a-z0-9-]/-/g' | tr -s '-')

if [[ -z "$HOST" ]]; then
  # Compute review-app host
  if [[ -z "$ROOT_DOMAIN" ]]; then
    HOST=$(echo "$ESCAPED_BRANCH")
  else
    HOST=$(echo "$ESCAPED_BRANCH.$ROOT_DOMAIN")
  fi
fi

echo "host=$HOST" >> $GITHUB_OUTPUT

if [[ -z "$REPOSITORY" ]]; then
  REPOSITORY=$GITHUB_REPOSITORY
fi

if [[ -z "$DATABASE_NAME" ]]; then
  # Compute database name
  DATABASE_NAME=$(echo "$ESCAPED_BRANCH" | sed -e 's/[^a-z0-9_]/_/g' | tr -s '_')
fi

echo "database_name=$DATABASE_NAME" >> $GITHUB_OUTPUT

AUTH_HEADER="Authorization: Bearer $FORGE_API_TOKEN"

echo ""
echo "* Check that stubs files exists"

if [ ! -e "/github/workspace/$ENV_STUB_PATH" ]; then
  echo ".env stub file not found at /github/workspace/$ENV_STUB_PATH"
  exit 1
fi

if [ ! -e "/github/workspace/$DEPLOY_SCRIPT_STUB_PATH" ]; then
  echo "Deploy script stub file not found at /github/workspace/$DEPLOY_SCRIPT_STUB_PATH"
  exit 1
fi

echo ".env and deploy script stub files found"

echo ""
echo '* Get Forge server sites'
API_URL="https://forge.laravel.com/api/v1/servers/$FORGE_SERVER_ID/sites"
JSON_RESPONSE=$(
  curl -s -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    "$API_URL"
)
echo "$JSON_RESPONSE" > sites.json

# Check if review-app site exists
SITE_DATA=$(jq -r '.sites[] | select(.name == "'"$HOST"'") // empty' sites.json)
if [[ ! -z "$SITE_DATA" ]]; then
  echo "$SITE_DATA" > site.json
  SITE_ID=$(jq -r '.id' site.json)
  echo "A site (ID $SITE_ID) name match the host"
  RA_FOUND='true'
else
  echo "Site $HOST not found"
  RA_FOUND='false'
fi

if [[ $RA_FOUND == 'false' ]]; then
  echo ""
  echo "* Create review-app site"

  API_URL="https://forge.laravel.com/api/v1/servers/$FORGE_SERVER_ID/sites"

  if [[ $CREATE_DATABASE == 'true' ]]; then
    JSON_PAYLOAD='{
      "domain": "'"$HOST"'",
      "project_type": "'"$PROJECT_TYPE"'",
      "directory": "'"$DIRECTORY"'",
      "isolated": '"$ISOLATED"',
      "php_version": "'"$PHP_VERSION"'",
      "database": "'"$DATABASE_NAME"'"
    }'
  else
    JSON_PAYLOAD='{
      "domain": "'"$HOST"'",
      "project_type": "'"$PROJECT_TYPE"'",
      "directory": "'"$DIRECTORY"'",
      "isolated": '"$ISOLATED"',
      "php_version": "'"$PHP_VERSION"'"
    }'
  fi

  HTTP_STATUS=$(
    curl -s -o response.json -w "%{http_code}" \
      -X POST \
      -H "$AUTH_HEADER" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -d "$JSON_PAYLOAD" \
      "$API_URL"
  )

  JSON_RESPONSE=$(cat response.json)

  if [[ $HTTP_STATUS -eq 200 ]]; then
    echo $(jq '.site' response.json) > site.json
    SITE_ID=$(jq -r '.id' site.json)

    if [[ $CREATE_DATABASE == 'true' ]]; then
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

  API_URL="https://forge.laravel.com/api/v1/servers/$FORGE_SERVER_ID/sites/$SITE_ID/git"

  JSON_PAYLOAD='{
    "provider": "'"$REPOSITORY_PROVIDER"'",
    "repository": "'"$REPOSITORY"'",
    "branch": "'"$BRANCH"'",
    "composer": '"$COMPOSER"'
  }'

  HTTP_STATUS=$(
    curl -s -o response.json -w "%{http_code}" \
      -X POST \
      -H "$AUTH_HEADER" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -d "$JSON_PAYLOAD" \
      "$API_URL"
  )

  JSON_RESPONSE=$(cat response.json)

  if [[ $HTTP_STATUS -eq 200 ]]; then
    echo "Git repository configured successfully"
  else
    echo "Failed to setup git repository on Forge site. HTTP status code: $HTTP_STATUS"
    echo "JSON Response:"
    echo "$JSON_RESPONSE"
    exit 1
  fi
fi

if [[ $REPOSITORY_CONFIGURED == 'true' ]]; then
  echo ""
  echo "* Check if site has a certificate"

  API_URL="https://forge.laravel.com/api/v1/servers/$FORGE_SERVER_ID/sites/$SITE_ID/certificates"

  HTTP_STATUS=$(
    curl -s -o response.json -w "%{http_code}" \
    -X GET \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "$API_URL"
  )

  if [[ $HTTP_STATUS -eq 200 ]]; then
    echo "Fetched site certificates successfully"
    if jq -e '.certificates | length > 0' response.json > /dev/null; then
      echo "Site has at least one certificate"
      CERTIFICATE_FOUND='true'
    else
      echo "Site has no certificate"
      CERTIFICATE_FOUND='false'
    fi
  else
    echo "Failed to fetch site certificates. HTTP status code: $HTTP_STATUS"
    echo "JSON Response:"
    cat response.json
    exit 1
  fi

  if [[ $CERTIFICATE_FOUND == 'false' ]]; then
    echo ""
    echo "* Obtain Let's Encrypt certificate"

    API_URL="https://forge.laravel.com/api/v1/servers/$FORGE_SERVER_ID/sites/$SITE_ID/certificates/letsencrypt"

    JSON_PAYLOAD='{
      "domains": ["'"$HOST"'"]
    }'

    HTTP_STATUS=$(
      curl -s -o response.json -w "%{http_code}" \
        -X POST \
        -H "$AUTH_HEADER" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -d "$JSON_PAYLOAD" \
        "$API_URL"
    )

    JSON_RESPONSE=$(cat response.json)

    if [[ $HTTP_STATUS -eq 200 ]]; then
      echo "Request for a let's encrypt certificate sent successfully"
      echo "$(jq -r '.certificate' response.json)" > certificate.json
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

    API_URL="https://forge.laravel.com/api/v1/servers/$FORGE_SERVER_ID/sites/$SITE_ID/certificates/$CERTIFICATE_ID"

    start_time=$(date +%s)
    elapsed_time=0
    status=""

    while [[ "$status" != "installed" && "$elapsed_time" -lt 120 ]]; do
      HTTP_STATUS=$(
        curl -s -o response.json -w "%{http_code}" \
        -X GET \
        -H "$AUTH_HEADER" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        "$API_URL"
      )

      JSON_RESPONSE=$(cat response.json)

      if [[ "$HTTP_STATUS" != "200" ]]; then
        echo "Response code is not 200 but $HTTP_STATUS"
        echo "API Response:"
        echo "$JSON_RESPONSE"
        exit 1
      fi

      status=$(echo "$JSON_RESPONSE" | jq -r '.certificate."status"')

      if [[ "$status" != "installed" ]]; then
        echo "Status is not "installed" ($status), retrying in 5 seconds..."
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

cp /github/workspace/$ENV_STUB_PATH .env

sed -i -e "s#STUB_HOST#$HOST#" .env
sed -i -e "s#STUB_DATABASE_NAME#$DATABASE_NAME#" .env
sed -i -e "s#STUB_DATABASE_USER#$DATABASE_USER#" .env
sed -i -e "s#STUB_DATABASE_PASSWORD#$DATABASE_PASSWORD#" .env

ENV_CONTENT=$(cat .env)
ESCAPED_ENV_CONTENT=$(echo "$ENV_CONTENT" | jq -Rsa .)

API_URL="https://forge.laravel.com/api/v1/servers/$FORGE_SERVER_ID/sites/$SITE_ID/env"

JSON_PAYLOAD='{
  "content": '"$ESCAPED_ENV_CONTENT"'
}'

HTTP_STATUS=$(
  curl -s -o response.json -w "%{http_code}" \
    -X PUT \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" \
    "$API_URL"
)

JSON_RESPONSE=$(cat response.json)

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

cp /github/workspace/$DEPLOY_SCRIPT_STUB_PATH deploy-script

sed -i -e "s#STUB_HOST#$HOST#" deploy-script

DEPLOY_SCRIPT_CONTENT=$(cat deploy-script)
ESCAPED_DEPLOY_SCRIPT_CONTENT=$(echo "$DEPLOY_SCRIPT_CONTENT" | jq -Rsa .)

API_URL="https://forge.laravel.com/api/v1/servers/$FORGE_SERVER_ID/sites/$SITE_ID/deployment/script"

JSON_PAYLOAD='{
  "content": '"$ESCAPED_DEPLOY_SCRIPT_CONTENT"',
  "auto_source": true
}'

HTTP_STATUS=$(
  curl -s -o response.json -w "%{http_code}" \
    -X PUT \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" \
    "$API_URL"
)

JSON_RESPONSE=$(cat response.json)

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

API_URL="https://forge.laravel.com/api/v1/servers/$FORGE_SERVER_ID/sites/$SITE_ID/deployment/deploy"

HTTP_STATUS=$(
  curl -s -o response.json -w "%{http_code}" \
    -X POST \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "$API_URL"
)

JSON_RESPONSE=$(cat response.json)

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

API_URL="https://forge.laravel.com/api/v1/servers/$FORGE_SERVER_ID/sites/$SITE_ID"

start_time=$(date +%s)
elapsed_time=0
status=""

while [[ "$status" != "null" && "$elapsed_time" -lt 60 ]]; do
  HTTP_STATUS=$(
    curl -s -o response.json -w "%{http_code}" \
    -X GET \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "$API_URL"
  )

  JSON_RESPONSE=$(cat response.json)

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

API_URL="https://forge.laravel.com/api/v1/servers/$FORGE_SERVER_ID/sites/$SITE_ID/deployment-history"

HTTP_STATUS=$(
curl -s -o response.json -w "%{http_code}" \
  -X GET \
  -H "$AUTH_HEADER" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "$API_URL"
)

if [[ $HTTP_STATUS -eq 200 ]]; then
  echo "Fetched last deployment successfully "
  echo "$(jq -r '.deployments[0]' response.json)" > last-deployment.json
else
  echo "Failed to launch deployment. HTTP status code: $HTTP_STATUS"
  echo "JSON Response:"
  cat response.json
  exit 1
fi

echo ""
echo "* Get last deployment output"

LAST_DEPLOYMENT_DATA=$(cat last-deployment.json)
LAST_DEPLOYMENT_ID=$(echo "$LAST_DEPLOYMENT_DATA" | jq '.id')

API_URL="https://forge.laravel.com/api/v1/servers/$FORGE_SERVER_ID/sites/$SITE_ID/deployment-history/$LAST_DEPLOYMENT_ID/output"

HTTP_STATUS=$(
  curl -s -o response.json -w "%{http_code}" \
    -X GET \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "$API_URL"
)

JSON_RESPONSE=$(cat response.json)

if [[ $HTTP_STATUS -eq 200 ]]; then
  echo "Fetched last deployment output successfully "
  echo "$JSON_RESPONSE" > last-deployment-output.json
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
LAST_DEPLOYMENT_OUTPUT_DATA=$(cat last-deployment-output.json)
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