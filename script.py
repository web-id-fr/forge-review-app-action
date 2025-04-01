import os
import re
import requests
import json
from dotenv import load_dotenv

load_dotenv()

def get_env_var(name, default=None):
    return os.getenv(name, default)

def debug_log(message):
    """ Show debug message if DEBUG is set to true """
    if get_env_var('DEBUG', 'false') == 'true':
        print(f"[DEBUG] {message}")

def sanitize_branch_name(branch):
    escaped = re.sub(r'[^a-z0-9-]', '-', branch.lower())
    escaped = re.sub(r'-+', '-', escaped).strip('-')
    return escaped

def compute_host(escaped_branch, root_domain, fqdn_prefix=None):
    if fqdn_prefix:
        fqdn_prefix = fqdn_prefix.replace('.', '')
        host = f"{fqdn_prefix}.{escaped_branch}.{root_domain}"
    else:
        host = f"{escaped_branch}.{root_domain}"

    if len(host) > 64:
        excess_length = len(host) - 64
        truncated_branch = escaped_branch[:-excess_length]
        if fqdn_prefix:
            host = f"{fqdn_prefix}.{truncated_branch}.{root_domain}"
        else:
            host = f"{truncated_branch}.{root_domain}"

    return re.sub(f'-\\.{root_domain}', f'.{root_domain}', host)

def load_env_file(env_path):
    """ Load .env file and replace placeholders with actual values """
    with open(env_path, 'r') as file:
        env_content = file.read()

    env_content = env_content.replace('STUB_FULL_DOMAIN', INPUT_FULL_DOMAIN)
    env_content = env_content.replace('STUB_HOST', INPUT_HOST)
    env_content = env_content.replace('STUB_DATABASE_NAME', INPUT_DATABASE_NAME)
    env_content = env_content.replace('STUB_DATABASE_USER', 'forge')
    env_content = env_content.replace('STUB_DATABASE_PASSWORD', 'toto')

    return env_content

class ForgeAPI:
    def __init__(self):
        self.server_id = get_env_var('INPUT_FORGE_SERVER_ID')
        self.api_token = get_env_var('INPUT_FORGE_API_TOKEN')
        self.headers = {"Authorization": f"Bearer {self.api_token}"}

    def make_request(self, method, url, json_payload=None):
        debug_log(f"[API REQUEST] {method.upper()} {url} | Payload: {json.dumps(json_payload) if json_payload else 'None'}")
        response = requests.request(method, url, headers=self.headers, json=json_payload)
        if response.status_code >= 400:
            debug_log(f"Error response received: {response.text}")
            response.raise_for_status()
        return response

    def get_sites(self):
        return self.make_request("get", f"https://forge.laravel.com/api/v1/servers/{self.server_id}/sites").json()

    def create_site(self, host, project_type, directory, php_version, database_name=None, nginx_template=None):
        payload = {
            "domain": host,
            "project_type": project_type,
            "directory": directory,
            "php_version": php_version,
            "isolated": get_env_var('INPUT_ISOLATED', 'false') == 'true'
        }
        if database_name:
            payload["database"] = database_name
        if nginx_template:
            payload["nginx_template"] = nginx_template
        return self.make_request("post", f"https://forge.laravel.com/api/v1/servers/{self.server_id}/sites", payload).json()

    def update_env_file(self, site_id, env_content):
        response = self.make_request("put", f"https://forge.laravel.com/api/v1/servers/{self.server_id}/sites/{site_id}/env", {"content": env_content})
        try:
            response.json()
        except json.JSONDecodeError:
            debug_log(f"Non-JSON response received: {response.text}")
            response.raise_for_status()

    def configure_deploy_script(self, site_id, script_content):
        payload = {
            "content": script_content,
            "auto_source": get_env_var('INPUT_DEPLOYMENT_AUTO_SOURCE', 'true') == 'true'
        }
        response = self.make_request("put", f"https://forge.laravel.com/api/v1/servers/{self.server_id}/sites/{site_id}/deployment/script", payload)
        try:
            response.json()
        except json.JSONDecodeError:
            debug_log(f"Non-JSON response received: {response.text}")
            response.raise_for_status()

    def deploy_site(self, site_id):
        return self.make_request("post", f"https://forge.laravel.com/api/v1/servers/{self.server_id}/sites/{site_id}/deployment/deploy").json()

    def get_certificates(self, site_id):
        return self.make_request("get", f"https://forge.laravel.com/api/v1/servers/{self.server_id}/sites/{site_id}/certificates").json()

    def request_ssl_certificate(self, site_id, domain):
        return self.make_request("post", f"https://forge.laravel.com/api/v1/servers/{self.server_id}/sites/{site_id}/certificates/letsencrypt", {"domains": [domain]}).json()

    def configure_repository(self, site_id, repository, branch, provider, composer):
        payload = {
            "provider": provider,
            "repository": repository,
            "branch": branch,
            "composer": composer == 'true'
        }
        return self.make_request("post", f"https://forge.laravel.com/api/v1/servers/{self.server_id}/sites/{site_id}/git", payload)

if __name__ == "__main__":
    # Initialisation des variables
    print("🚀 Initialisation des variables...")

    INPUT_BRANCH = get_env_var('GITHUB_HEAD_REF', 'main')
    ESCAPED_BRANCH = sanitize_branch_name(INPUT_BRANCH)
    INPUT_FQDN_PREFIX = get_env_var('INPUT_FQDN_PREFIX')
    INPUT_ROOT_DOMAIN = get_env_var('INPUT_ROOT_DOMAIN')
    INPUT_HOST = compute_host(ESCAPED_BRANCH, INPUT_ROOT_DOMAIN, INPUT_FQDN_PREFIX)
    INPUT_FULL_DOMAIN = compute_host(ESCAPED_BRANCH, INPUT_ROOT_DOMAIN)
    INPUT_DATABASE_NAME = re.sub(r'[^a-z0-9_]', '_', ESCAPED_BRANCH).strip('_')[:63]

    INPUT_PROJECT_TYPE = get_env_var('INPUT_PROJECT_TYPE', 'php')
    INPUT_DIRECTORY = get_env_var('INPUT_DIRECTORY', '/public')
    INPUT_ISOLATED = get_env_var('INPUT_ISOLATED', 'false')
    INPUT_PHP_VERSION = get_env_var('INPUT_PHP_VERSION', 'php81')
    INPUT_CREATE_DATABASE = get_env_var('INPUT_CREATE_DATABASE', 'false')
    INPUT_DATABASE_USER = get_env_var('INPUT_DATABASE_USER', 'forge')
    INPUT_CONFIGURE_REPOSITORY = get_env_var('INPUT_CONFIGURE_REPOSITORY', 'true')
    INPUT_REPOSITORY_PROVIDER = get_env_var('INPUT_REPOSITORY_PROVIDER', 'github')
    INPUT_COMPOSER = get_env_var('INPUT_COMPOSER', 'false')
    INPUT_LETSENCRYPT_CERTIFICATE = get_env_var('INPUT_LETSENCRYPT_CERTIFICATE', 'true')
    INPUT_CERTIFICATE_SETUP_TIMEOUT = get_env_var('INPUT_CERTIFICATE_SETUP_TIMEOUT', '120')
    INPUT_ENV_STUB_PATH = get_env_var('INPUT_ENV_STUB_PATH', '.github/workflows/.env.stub')
    INPUT_DEPLOY_SCRIPT_STUB_PATH = get_env_var('INPUT_DEPLOY_SCRIPT_STUB_PATH', '.github/workflows/deploy-script.stub')
    INPUT_DEPLOYMENT_TIMEOUT = get_env_var('INPUT_DEPLOYMENT_TIMEOUT', '120')
    INPUT_DEPLOYMENT_AUTO_SOURCE = get_env_var('INPUT_DEPLOYMENT_AUTO_SOURCE', 'true')
    INPUT_CREATE_WORKER = get_env_var('INPUT_CREATE_WORKER', 'false')
    INPUT_WORKER_CONNECTION = get_env_var('INPUT_WORKER_CONNECTION', 'redis')
    INPUT_WORKER_TIMEOUT = get_env_var('INPUT_WORKER_TIMEOUT', '90')
    INPUT_WORKER_SLEEP = get_env_var('INPUT_WORKER_SLEEP', '60')
    INPUT_WORKER_PROCESSES = get_env_var('INPUT_WORKER_PROCESSES', '1')
    INPUT_WORKER_STOPWAITSECS = get_env_var('INPUT_WORKER_STOPWAITSECS', '600')
    INPUT_WORKER_PHP_VERSION = get_env_var('INPUT_WORKER_PHP_VERSION', INPUT_PHP_VERSION)
    INPUT_WORKER_DAEMON = get_env_var('INPUT_WORKER_DAEMON', 'true')
    INPUT_WORKER_FORCE = get_env_var('INPUT_WORKER_FORCE', 'false')

    # Connect to Forge API
    forge = ForgeAPI()

    # Check if site already exists
    print(f"🔎 Checking the site: {INPUT_HOST}")
    sites = forge.get_sites()
    SITE_DATA = next((site for site in sites.get('sites', []) if site['name'] == INPUT_HOST), None)

    if SITE_DATA:
        SITE_ID = SITE_DATA['id']
        print(f"✅ Existing site found: {INPUT_HOST} (ID: {SITE_ID})")
    else:
        print(f"⚠️ Site {INPUT_HOST} not found. Creating...")
        response = forge.create_site(
            INPUT_HOST,
            get_env_var('INPUT_PROJECT_TYPE', 'php'),
            get_env_var('INPUT_DIRECTORY', '/public'),
            get_env_var('INPUT_PHP_VERSION', 'php81'),
            INPUT_DATABASE_NAME
        )
        SITE_ID = response.get('site', {}).get('id')
        if SITE_ID:
            print(f"✅ New site created: {INPUT_HOST} (ID: {SITE_ID})")
        else:
            print(f"❌ Failed to create site: {response}")
            exit(1)

    # Git repository configuration
    if get_env_var('INPUT_CONFIGURE_REPOSITORY', 'true') == 'true':
        print("📂 Checking the Git repository...")
        SITE_REPOSITORY = SITE_DATA.get('repository') if SITE_DATA else None

        if not SITE_REPOSITORY:
            print("⚠️ Repository not configured. Configuring...")
            response = forge.configure_repository(
                SITE_ID,
                get_env_var('INPUT_REPOSITORY'),
                INPUT_BRANCH,
                get_env_var('INPUT_REPOSITORY_PROVIDER', 'github'),
                get_env_var('INPUT_COMPOSER', 'false')
            )
            if response.status_code == 200:
                print("✅ Repository configured successfully.")
            else:
                print(f"❌ Failed to configure repository: {response}")
                exit(1)
        else:
            print(f"✅ Repository already configured: {SITE_REPOSITORY}")

    # Updating the .env file
    print("📄 Updating the .env file...")
    env_stub_path = get_env_var('INPUT_ENV_STUB_PATH', '.github/workflows/.env.stub')
    env_content = load_env_file(env_stub_path)
    forge.update_env_file(SITE_ID, env_content)
    print("✅ .env file updated successfully.")

    # SSL certificate verification and request
    if get_env_var('INPUT_LETSENCRYPT_CERTIFICATE', 'true') == 'true':
        print("🔐 Verifying SSL certificate...")
        certs = forge.get_certificates(SITE_ID).get('certificates', [])
        if not certs:
            print("⚠️ No certificate found. Requesting...")
            forge.request_ssl_certificate(SITE_ID, INPUT_HOST)
            print("✅ SSL certificate requested.")

    # Deployment script configuration
    print("📜 Configuring deployment script...")
    deploy_script_stub_path = get_env_var('INPUT_DEPLOY_SCRIPT_STUB_PATH', '.github/workflows/deploy-script.stub')
    with open(deploy_script_stub_path, 'r') as file:
        deploy_script_content = file.read().replace('STUB_HOST', INPUT_HOST)

    forge.configure_deploy_script(SITE_ID, deploy_script_content)
    print("✅ Deployment script configured successfully.")

    # Final deployment
    print("🚀 Starting deployment...")
    forge.deploy_site(SITE_ID)
    print("✅ Deployment successfully started.")