# Laravel Forge Review App GitHub Action

Deploy your application to [Laravel Forge](https://forge.laravel.com) with GitHub Actions.
Create/update and deploy a review-application to [Laravel Forge](https://forge.laravel.com) with GitHub action.

## Inputs

It is highly recommended that you store all inputs using [GitHub Secrets](https://docs.github.com/en/actions/reference/encrypted-secrets) or variables.

| Input                       | Required | Default                                | Description                                                                                                                        |
|-----------------------------|----------|----------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| `forge_api_token`           | yes      |                                        | Laravel Forge API key.<br>You can generate an API key in your [Forge dashboard](https://forge.laravel.com/user-profile/api).       |
| `forge_server_id`           | yes      |                                        | Laravel Forge server ID                                                                                                            |
| `root_domain`               | no       |                                        | Root domain under which to create review-app site.                                                                                 |
| `host`                      | no       |                                        | Site host of the review-app.<br>The branch name the action is running on will be used to generate it if not defined (recommended). |
| `project_type`              | no       | `php`                                  | Project type of the review-app.                                                                                                    |
| `directory`                 | no       | `/public`                              | Root directory for nginx configuration of the review-app.                                                                          |
| `isolated`                  | no       | `false`                                | Isolate review-app site.                                                                                                           |
| `php_version`               | no       | `php81`                                | PHP version of the review-app site.                                                                                                |
| `create_database`           | no       | `false`                                | Create database for review-app.                                                                                                    |
| `database_user`             | no       | `forge`                                | Database user of the review-app site.                                                                                              |
| `database_password`         | no       |                                        | Database password of the review-app site.<br>Mandatory if `create_database` is set to `true`                                       |
| `database_name`             | no       |                                        | Database name of the review-app site (recommended).                                                                                |
| `configure_repository`      | no       | `true`                                 | Configure repository on review-app site.                                                                                           |
| `repository_provider`       | no       | `github`                               | Repository provider of review-app site.                                                                                            |
| `repository`                | no       |                                        | Repository of review-app site.<br>The repository name the action is running on will be used to generate it if not defined.         |
| `branch`                    | no       |                                        | Git branch to use.<br>The branch name the action is running on will be used to generate it if not defined.                         |
| `composer`                  | no       | `false`                                | Composer install on repository setup.                                                                                              |
| `letsencrypt_certificate`   | no       | `true`                                 | Obtain LetsEncrypt certificate for the review-app site.                                                                            |
| `certificate_setup_timeout` | no       | `120`                                  | Maximum wait time in seconds for obtaining the certificate.                                                                        |
| `env_stub_path`             | no       | `.env.example`                         | .env stub file path inside git repository.                                                                                         |
| `deploy_script_stub_path`   | no       | `.github/workflows/deploy-script.stub` | Deploy script stub file path inside the git repository.                                                                            |
| `deployment_timeout`        | no       | `120`                                  | Maximum wait time in seconds for deploying.                                                                                        |

## Outputs

| Output          | Description                                                          |
|-----------------|----------------------------------------------------------------------|
| `host`          | Host of the review-app (generated or forced one in inputs).          |
| `database_name` | Database name of the review-app (generated or forced one in inputs). |

## .env stub file

String replacement map:

| String                   | Replacement                          |
|--------------------------|--------------------------------------|
| `STUB_HOST`              | Host name of the review-app site.    |
| `STUB_DATABASE_NAME`     | Database name of the review-app.     |
| `STUB_DATABASE_USER`     | Database user of the review-app.     |
| `STUB_DATABASE_PASSWORD` | Database password of the review-app. |

## Deploy script stub file

String replacement map:

| String                   | Replacement                          |
|--------------------------|--------------------------------------|
| `STUB_HOST`              | Host name of the review-app site.    |

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
      # Trigger Laravel Forge Deploy
      - name: Deploy
        uses: web-id-fr/forge-review-app-action@v1.0.0
        with:
          forge_api_token: ${{ secrets.FORGE_API_TOKEN }}
          forge_server_id: ${{ secrets.FORGE_SERVER_ID }}
          create_database: 'true'
          database_password: ${{ secrets.FORGE_DB_PASSWORD }}
```

## Credits

- [Ryan Gilles](https://www.linkedin.com/in/ryan-gilles-293680174/)

## License

The MIT License (MIT). Please see [License File](LICENSE.md) for more information.