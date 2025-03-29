import os
import re
import subprocess
import requests
import json

def get_env_var(name, default=None):
    return os.getenv(name, default)

def debug_log(message):
    if get_env_var('DEBUG', 'false') == 'true':
        print(f"[DEBUG] {message}")

# Prepare vars and default values
DEBUG = get_env_var('DEBUG', 'false')
if DEBUG == 'true':
    print("!!! DEBUG MODE ENABLED !!!")

INPUT_BRANCH = get_env_var('GITHUB_HEAD_REF')
INPUT_PREFIX_WITH_PR_NUMBER = get_env_var('INPUT_PREFIX_WITH_PR_NUMBER', 'true')

ESCAPED_BRANCH = re.sub(r'[^a-z0-9-]', '-', INPUT_BRANCH).strip('-')

if INPUT_PREFIX_WITH_PR_NUMBER == 'true':
    match = re.search(r'\d+', get_env_var('GITHUB_REF_NAME'))
    if match:
        PR_NUMBER = match.group(0)
        ESCAPED_BRANCH = f"{ESCAPED_BRANCH}"

# More variables initialization
INPUT_HOST = get_env_var('INPUT_HOST')
INPUT_ROOT_DOMAIN = get_env_var('INPUT_ROOT_DOMAIN')
INPUT_FQDN_PREFIX = get_env_var('INPUT_FQDN_PREFIX')

### PART 2 ###

if not INPUT_HOST:
    if not INPUT_ROOT_DOMAIN:
        INPUT_HOST = ESCAPED_BRANCH
        if INPUT_FQDN_PREFIX:
            INPUT_HOST = f"{INPUT_FQDN_PREFIX}{INPUT_HOST}"
        INPUT_HOST = INPUT_HOST[:64].rstrip('-')
    else:
        INPUT_HOST = f"{ESCAPED_BRANCH}.{INPUT_ROOT_DOMAIN}"
        if INPUT_FQDN_PREFIX:
            INPUT_HOST = f"{INPUT_FQDN_PREFIX}{INPUT_HOST}"
        if len(INPUT_HOST) > 64:
            INPUT_HOST = f"{ESCAPED_BRANCH[:64 - len(INPUT_ROOT_DOMAIN) - 1]}.{INPUT_ROOT_DOMAIN}"
        INPUT_HOST = re.sub(r'-\.' + re.escape(INPUT_ROOT_DOMAIN), '.' + INPUT_ROOT_DOMAIN, INPUT_HOST)

if get_env_var('GITHUB_ACTIONS') == 'true':
    with open(os.getenv('GITHUB_OUTPUT'), 'a') as f:
        f.write(f"host={INPUT_HOST}\n")

INPUT_REPOSITORY = get_env_var('INPUT_REPOSITORY', get_env_var('GITHUB_REPOSITORY'))
INPUT_DATABASE_NAME = get_env_var('INPUT_DATABASE_NAME', re.sub(r'[^a-z0-9_]', '_', ESCAPED_BRANCH).strip('_'))
INPUT_DATABASE_NAME_PREFIX = get_env_var('INPUT_DATABASE_NAME_PREFIX')
if INPUT_DATABASE_NAME_PREFIX:
    INPUT_DATABASE_NAME = f"{INPUT_DATABASE_NAME_PREFIX}{INPUT_DATABASE_NAME}"
INPUT_DATABASE_NAME = INPUT_DATABASE_NAME[:63]

if get_env_var('GITHUB_ACTIONS') == 'true':
    with open(os.getenv('GITHUB_OUTPUT'), 'a') as f:
        f.write(f"database_name={INPUT_DATABASE_NAME}\n")

### PART 3 ###

AUTH_HEADER = {"Authorization": f"Bearer {get_env_var('INPUT_FORGE_API_TOKEN')}"}
API_URL = f"https://forge.laravel.com/api/v1/servers/{get_env_var('INPUT_FORGE_SERVER_ID')}/sites"

debug_log(f"CURL GET on {API_URL}")
response = requests.get(API_URL, headers=AUTH_HEADER)
sites = response.json().get('sites', [])

SITE_DATA = next((site for site in sites if site['name'] == INPUT_HOST), None)
if SITE_DATA:
    SITE_ID = SITE_DATA['id']
    if get_env_var('GITHUB_ACTIONS') == 'true':
        with open(os.getenv('GITHUB_OUTPUT'), 'a') as f:
            f.write(f"site_id={SITE_ID}\n")
    print(f"A site (ID {SITE_ID}) name match the host")
    RA_FOUND = True
else:
    print(f"Site {INPUT_HOST} not found")
    RA_FOUND = False

if not RA_FOUND:
    print("* Create review-app site")
    API_URL = f"https://forge.laravel.com/api/v1/servers/{get_env_var('INPUT_FORGE_SERVER_ID')}/sites"
    JSON_PAYLOAD = {
        "domain": INPUT_HOST,
        "project_type": get_env_var('INPUT_PROJECT_TYPE', 'php'),
        "directory": get_env_var('INPUT_DIRECTORY', '/public'),
        "isolated": get_env_var('INPUT_ISOLATED', 'false') == 'true',
        "php_version": get_env_var('INPUT_PHP_VERSION', 'php81')
    }
    if get_env_var('INPUT_CREATE_DATABASE') == 'true':
        JSON_PAYLOAD["database"] = INPUT_DATABASE_NAME
    if get_env_var('INPUT_NGINX_TEMPLATE'):
        JSON_PAYLOAD["nginx_template"] = get_env_var('INPUT_NGINX_TEMPLATE')

    debug_log(f"CURL POST on {API_URL} with payload: {json.dumps(JSON_PAYLOAD)}")
    response = requests.post(API_URL, headers=AUTH_HEADER, json=JSON_PAYLOAD)
    if response.status_code == 200:
        SITE_ID = response.json()['site']['id']
        if get_env_var('GITHUB_ACTIONS') == 'true':
            with open(os.getenv('GITHUB_OUTPUT'), 'a') as f:
                f.write(f"site_id={SITE_ID}\n")
        print(f"New site (ID {SITE_ID}) created successfully")
    else:
        print(f"Failed to create new site. HTTP status code: {response.status_code}")
        print(f"JSON Response: {response.json()}")
        exit(1)


### PART 4 ###

# Check if repository is configured
if get_env_var('INPUT_CONFIGURE_REPOSITORY', 'true') == 'true':
    print("* Check if repository is configured")
    SITE_REPOSITORY = SITE_DATA['repository']
    if not SITE_REPOSITORY:
        print("Repository not configured on Forge site")
        REPOSITORY_CONFIGURED = False
    else:
        print(f"Repository configured on Forge site ({SITE_REPOSITORY})")
        REPOSITORY_CONFIGURED = True

    if not REPOSITORY_CONFIGURED:
        print("* Setup git repository on site")
        API_URL = f"https://forge.laravel.com/api/v1/servers/{get_env_var('INPUT_FORGE_SERVER_ID')}/sites/{SITE_ID}/git"
        print(f"PROVIDER : {get_env_var('INPUT_REPOSITORY_PROVIDER', 'github')}, REPOSITORY : {INPUT_REPOSITORY}, BRANCH : {INPUT_BRANCH}, COMPOSER : {get_env_var('INPUT_COMPOSER', 'false')}")
        JSON_PAYLOAD = {
            "provider": get_env_var('INPUT_REPOSITORY_PROVIDER', 'github'),
            "repository": INPUT_REPOSITORY,
            "branch": INPUT_BRANCH,
            "composer": get_env_var('INPUT_COMPOSER', 'false') == 'true'
        }
        debug_log(f"CURL POST on {API_URL} with payload: {json.dumps(JSON_PAYLOAD)}")
        response = requests.post(API_URL, headers=AUTH_HEADER, json=JSON_PAYLOAD)
        if response.status_code == 200:
            print("Git repository configured successfully")
        else:
            print(f"Failed to setup git repository on Forge site. HTTP status code: {response.status_code}")
            print(f"JSON Response: {response.json()}")
            exit(1)

# Check if site has a certificate
if get_env_var('INPUT_LETSENCRYPT_CERTIFICATE', 'true') == 'true':
    print("* Check if site has a certificate")
    API_URL = f"https://forge.laravel.com/api/v1/servers/{get_env_var('INPUT_FORGE_SERVER_ID')}/sites/{SITE_ID}/certificates"
    debug_log(f"CURL GET on {API_URL}")
    response = requests.get(API_URL, headers=AUTH_HEADER)
    if response.status_code == 200:
        certificates = response.json().get('certificates', [])
        if certificates:
            print("Site has at least one certificate")
            CERTIFICATE_FOUND = True
        else:
            print("Site has no certificate")
            CERTIFICATE_FOUND = False
    else:
        print(f"Failed to fetch site certificates. HTTP status code: {response.status_code}")
        print(f"JSON Response: {response.json()}")
        exit(1)

    if not CERTIFICATE_FOUND:
        print("* Obtain Let's Encrypt certificate")
        API_URL = f"https://forge.laravel.com/api/v1/servers/{get_env_var('INPUT_FORGE_SERVER_ID')}/sites/{SITE_ID}/certificates/letsencrypt"
        JSON_PAYLOAD = {"domains": [INPUT_HOST]}
        debug_log(f"CURL POST on {API_URL} with payload: {json.dumps(JSON_PAYLOAD)}")
        response = requests.post(API_URL, headers=AUTH_HEADER, json=JSON_PAYLOAD)
        if response.status_code == 200:
            CERTIFICATE_ID = response.json()['certificate']['id']
            print("Request for a let's encrypt certificate sent successfully")
        else:
            print(f"Failed to request let's encrypt certificate. HTTP status code: {response.status_code}")
            print(f"JSON Response: {response.json()}")
            exit(1)


### PART 5 ###
# Setup .env file
print("* Setup .env file")
env_stub_path = f"/github/workspace/{get_env_var('INPUT_ENV_STUB_PATH', '.github/workflows/.env.stub')}"
with open(env_stub_path, 'r') as file:
    env_content = file.read()

env_content = env_content.replace('STUB_HOST', INPUT_HOST)
env_content = env_content.replace('STUB_DATABASE_NAME', INPUT_DATABASE_NAME)
env_content = env_content.replace('STUB_DATABASE_USER', get_env_var('INPUT_DATABASE_USER', 'forge'))
env_content = env_content.replace('STUB_DATABASE_PASSWORD', get_env_var('INPUT_DATABASE_PASSWORD'))

debug_log(f"Generated .env file content:\n{env_content}")

escaped_env_content = json.dumps(env_content)
API_URL = f"https://forge.laravel.com/api/v1/servers/{get_env_var('INPUT_FORGE_SERVER_ID')}/sites/{SITE_ID}/env"
JSON_PAYLOAD = {"content": escaped_env_content}
debug_log(f"CURL POST on {API_URL} with payload: {json.dumps(JSON_PAYLOAD)}")
response = requests.put(API_URL, headers=AUTH_HEADER, json=JSON_PAYLOAD)
if response.status_code == 200:
    print(".env file updated successfully")
else:
    print(f"Failed to update .env file. HTTP status code: {response.status_code}")
    print(f"JSON Response: {response.json()}")
    exit(1)

# Setup deploy script
print("* Setup deploy script")
deploy_script_stub_path = f"/github/workspace/{get_env_var('INPUT_DEPLOY_SCRIPT_STUB_PATH', '.github/workflows/deploy-script.stub')}"
with open(deploy_script_stub_path, 'r') as file:
    deploy_script_content = file.read()

deploy_script_content = deploy_script_content.replace('STUB_HOST', INPUT_HOST)
escaped_deploy_script_content = json.dumps(deploy_script_content)
API_URL = f"https://forge.laravel.com/api/v1/servers/{get_env_var('INPUT_FORGE_SERVER_ID')}/sites/{SITE_ID}/deployment/script"
JSON_PAYLOAD = {
    "content": escaped_deploy_script_content,
    "auto_source": get_env_var('INPUT_DEPLOYMENT_AUTO_SOURCE', 'true') == 'true'
}
debug_log(f"CURL POST on {API_URL} with payload: {json.dumps(JSON_PAYLOAD)}")
response = requests.put(API_URL, headers=AUTH_HEADER, json=JSON_PAYLOAD)
if response.status_code == 200:
    print("Deployment script updated successfully")
else:
    print(f"Failed to update deployment script. HTTP status code: {response.status_code}")
    print(f"JSON Response: {response.json()}")
    exit(1)

# Launch deployment
print("* Launch deployment")
API_URL = f"https://forge.laravel.com/api/v1/servers/{get_env_var('INPUT_FORGE_SERVER_ID')}/sites/{SITE_ID}/deployment/deploy"
response = requests.post(API_URL, headers=AUTH_HEADER)
if response.status_code == 200:
    print("Deployment launched successfully")
else:
    print(f"Failed to launch deployment. HTTP status code: {response.status_code}")
    print(f"JSON Response: {response.json()}")
    exit(1)
