# Laravel Forge Review App GitHub Action

Create/update and deploy a review-application on [Laravel Forge](https://forge.laravel.com) with GitHub action.

## Description

This action allows you to automatically create/update and deploy a review-app site on a server managed by Forge when you open a pull-request or push to a branch.

It works in combination with this other action which removes the review-app site when closing the pull-request:
[web-id-fr/forge-review-app-clean-action](https://github.com/web-id-fr/forge-review-app-clean-action)

### Action running process

All steps are done using [Forge API](https://forge.laravel.com/api-documentation).

- Create site and database if not done yet.
- Configure repository.
- Obtain Let's Encrypt certificate.
- Setup .env file using [stub file](#stub-files).
- Setup deploy script using [stub file](#stub-files).
- Launch deployment.
- Check deployment and display result output.

### Optional inputs variables

The action will determines the name of the site (host) and the database if they are not specified (which is **recommended**).

The `host` is based on the branch name (escaping it with only `a-z0-9-` chars) and the `root_domain`.

For example, a `fix-37` branch with `mydomain.tld` root_domain will result in a `fix-37.mydomain.tld` host.

`database_name` is also based on the branch name (escaping it with only `a-z0-9_` chars).

### About stub files
<a name="stub-files"></a>

Stub files must be present on the github workspace of your running workflow before call this action.

You can achieve this using the [checkout action](https://github.com/actions/checkout) on a previous step like this:

```yaml
- name: Checkout stubs file
  uses: actions/checkout@v3
  with:
    sparse-checkout: |
      .github/workflows/.env.stub
      .github/workflows/deploy-script.stub
    sparse-checkout-cone-mode: false
```

#### .env stub file

You must create stub file at the path `.github/workflows/.env.stub` on your repository and checkout the file before running this action (see `env_stub_path` input below).

This file will be used as a template to generate the real content of the .env of the site, by replacing the following strings:

| String                   | Replacement                          |
|--------------------------|--------------------------------------|
| `STUB_HOST`              | Host name of the review-app site.    |
| `STUB_DATABASE_NAME`     | Database name of the review-app.     |
| `STUB_DATABASE_USER`     | Database user of the review-app.     |
| `STUB_DATABASE_PASSWORD` | Database password of the review-app. |

## Deploy script stub file

You must create stub file at the path `.github/workflows/deploy-script.stub` on your repository and checkout the file before running this action (see `deploy_script_stub_path` input below).

This file will be used as a template to generate the real content of the deploy script of the site, by replacing the following strings:

String replacement map:

| String                   | Replacement                          |
|--------------------------|--------------------------------------|
| `STUB_HOST`              | Host name of the review-app site.    |


## Inputs

It is highly recommended that you store all inputs using [GitHub Secrets](https://docs.github.com/en/actions/reference/encrypted-secrets) or variables.

| Input                       | Required | Default                                | Description                                                                                                                                 |
|-----------------------------|----------|----------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| `forge_api_token`           | yes      |                                        | Laravel Forge API key.<br>You can generate an API key in your [Forge dashboard](https://forge.laravel.com/user-profile/api).                |
| `forge_server_id`           | yes      |                                        | Laravel Forge server ID                                                                                                                     |
| `root_domain`               | no       |                                        | Root domain under which to create review-app site.                                                                                          |
| `host`                      | no       |                                        | Site host of the review-app.<br>The branch name the action is running on will be used to generate it if not defined (recommended).          |
| `prefix_with_pr_number`     | no       | `true`                                 | Use the pull-request number as host and database prefix when host is not manually defined.                                                  |
| `fqdn_prefix`               | no       |                                        | Prefix the whole FQDN (e.g.: "app.")                                                                                                        |
| `project_type`              | no       | `php`                                  | Project type of the review-app.                                                                                                             |
| `directory`                 | no       | `/public`                              | Root directory for nginx configuration of the review-app.                                                                                   |
| `isolated`                  | no       | `false`                                | Isolate review-app site.                                                                                                                    |
| `php_version`               | no       | `php81`                                | PHP version of the review-app site.                                                                                                         |
| `create_database`           | no       | `false`                                | Create database for review-app.                                                                                                             |
| `database_user`             | no       | `forge`                                | Database user of the review-app site.                                                                                                       |
| `database_password`         | no       |                                        | Database password of the review-app site.<br>Mandatory if `create_database` is set to `true`                                                |
| `database_name`             | no       |                                        | Database name of the review-app site.<br>The branch name the action is running on will be used to generate it if not defined (recommended). |
| `database_name_prefix`      | no       |                                        | Database name prefix, useful for PostgreSQL that does not support digits (PR number) for first chars.                                       |
| `nginx_template`            | no       |                                        | Nginx template to use (default template if not defined).                                                                                    |
| `configure_repository`      | no       | `true`                                 | Configure repository on review-app site.                                                                                                    |
| `repository_provider`       | no       | `github`                               | Repository provider of review-app site.                                                                                                     |
| `repository`                | no       |                                        | Repository of review-app site.<br>The repository name the action is running on will be used to generate it if not defined.                  |
| `branch`                    | no       |                                        | Git branch to use.<br>The branch name the action is running on will be used to generate it if not defined.                                  |
| `composer`                  | no       | `false`                                | Composer install on repository setup.                                                                                                       |
| `letsencrypt_certificate`   | no       | `true`                                 | Obtain LetsEncrypt certificate for the review-app site.                                                                                     |
| `certificate_setup_timeout` | no       | `120`                                  | Maximum wait time in seconds for obtaining the certificate.                                                                                 |
| `env_stub_path`             | no       | `.github/workflows/.env.stub`          | .env stub file path inside git repository.                                                                                                  |
| `deploy_script_stub_path`   | no       | `.github/workflows/deploy-script.stub` | Deploy script stub file path inside the git repository.                                                                                     |
| `deployment_timeout`        | no       | `120`                                  | Maximum wait time in seconds for deploying.                                                                                                 |
| `deployment_auto_source`    | no       | `true`                                 | Whether to automatically source environment variables into the deployment script.                                                           |
| `create_worker`             | no       | `false`                                | Create site worker.                                                                                                                         |
| `worker_connection`         | no       | `redis`                                | Worker connection (if creation is requested).                                                                                               |
| `worker_timeout`            | no       | `90`                                   | Worker timeout in seconds (if creation is requested).                                                                                       |
| `worker_sleep`              | no       | `60`                                   | Worker sleep time in seconds (if creation is requested).                                                                                    |
| `worker_tries`              | no       |                                        | Worker maximum tries (if creation is requested).                                                                                            |
| `worker_processes`          | no       | `1`                                    | Worker processes (if creation is requested).                                                                                                |
| `worker_stopwaitsecs`       | no       | `600`                                  | Worker stop wait secs (if creation is requested).                                                                                           |
| `worker_php_version`        | no       |                                        | Worker PHP version (if creation is requested). `php_version` input value will be used if not defined.                                       |
| `worker_daemon`             | no       | `true`                                 | Worker "daemon" (if creation is requested).                                                                                                 |
| `worker_force`              | no       | `false`                                | Worker "force" (if creation is requested).                                                                                                  |
| `worker_queue`              | no       |                                        | Worker queue (if creation is requested). Default queue will be used if not defined.                                                         |
| `horizon_enabled`           | no       | `false`                                | Enable Laravel Horizon integration.                                                                                                         |
| `scheduler_enabled`         | no       | `false`                                | Enable Laravel Scheduler integration.                                                                                                       |
| `quick_deploy_enabled`      | no       | `false`                                | Enable quick deployment trigger.                                                                                                            |


## Outputs

| Output          | Description                                                           |
|-----------------|-----------------------------------------------------------------------|
| `host`          | Host of the review-app (generated or forced one in inputs).           |
| `database_name` | Database name of the review-app (generated or forced one in inputs).  |
| `site_id`       | Forge site ID of the review-app.                                      |
| `worker_id`     | Worker ID.                                                            |

You can easily use those outputs variables to generate a message on your pull-request with this action next:

```yaml
- name: PR Comment
  uses: unsplash/comment-on-pr@v1.3.0
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    msg: ":rocket: Review-app available here: https://${{ steps.forge-review-app.outputs.host }}"
```

## Examples

Create or update a review-app on opened pull-requests:

```yml
name: review-app
on:
  pull_request:
    types: [ 'opened', 'reopened', 'synchronize', 'ready_for_review' ]

jobs:
  review-app:
    runs-on: ubuntu-latest
    name: "Create or update Forge review-app"

    steps:
      - name: Deploy
        uses: web-id-fr/forge-review-app-action@v1.0.0
        with:
          forge_api_token: ${{ secrets.FORGE_API_TOKEN }}
          forge_server_id: ${{ secrets.FORGE_SERVER_ID }}
          create_database: 'true'
          database_password: ${{ secrets.FORGE_DB_PASSWORD }}
```

## Testing

We use [bats-core](https://github.com/bats-core/bats-core) for tests.


### Using Docker

Run tests using docker, locally:

```bash
docker run --rm -it $(docker build -q -f Dockerfile.test .) /code/test
```

### From your host

Prerequisites:

- bash
- curl
- jq
- shellcheck
- nodejs
- npm

Setup bats-core dependencies using npm, then run tests:

```bash
npm install
npm run test
```

## Credits

- [Ryan Gilles](https://www.linkedin.com/in/ryan-gilles-293680174/)

## License

The MIT License (MIT). Please see [License File](LICENSE.md) for more information.
