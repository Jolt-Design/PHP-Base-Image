# AGENTS.md

Source for the `joltdesign/php` Docker Hub image: the official `php:<version>-apache` image plus the extensions WordPress needs (redis, imagick, mcrypt, gd, intl, zip, exif, mysqli, pdo_mysql, opcache) and Jolt's default PHP/Apache config. Images are built with Docker Buildx Bake: one target per PHP version × runtime × prod/dev. There is no application code and there are no tests. The only output is the published images.

## Stack and layout

| What                                                                                    | Where                                                                    |
| --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| PHP versions built (8.2, 8.3, 8.4, 8.5)                                                 | `versions.json`: the source of truth for `yarn build` and GitHub Actions |
| Bake targets, tags, per-version overrides (`dependency_versions`)                       | `docker-bake.hcl`                                                        |
| Image definition: `production` stage, then `dev` stage (php.ini-development + Xdebug)   | `build/Dockerfile`                                                       |
| PHP ini files copied into every image / dev only                                        | `build/php-conf.d/`, `build/dev-php-conf.d/`                             |
| Apache config copied into `conf-enabled`                                                | `build/apache-conf.d/`                                                   |
| Wrapper that sets `PHP_VERSIONS` from `versions.json` and runs `docker buildx bake`     | `bin/bake.js`                                                            |
| Yarn 4.18.1 with Plug'n'Play (no `node_modules`)                                        | `packageManager` in `package.json`, `.pnp.cjs`                           |
| `jolt` CLI (`@joltdesign/scripts`)                                                      | `devDependencies` in `package.json`                                      |
| OpenTofu: only reads the CodeBuild project name from shared-infrastructure remote state | `data.tf` (local state, gitignored)                                      |

- Extensions are installed with PIE (`pie install vendor/package[:version]`), not PECL.
- Only the `apache` runtime is built (`fpm` is commented out in `runtimes`).
- Tags: `<ver>-apache[-dev]`, `<ver>[-dev]` (default runtime) and `latest[-dev]` (highest version).
- Use `yarn <bin>` (e.g. `yarn jolt`), never `npx`. PnP has no `node_modules/.bin`.

## Commands

| Task                                                                         | Command                                                  |
| ---------------------------------------------------------------------------- | -------------------------------------------------------- |
| Install deps                                                                 | `yarn install`                                           |
| Full setup (Husky hooks, `tofu init`, `tofu refresh`; needs AWS credentials) | `yarn prepare`                                           |
| Show resolved bake config (no build)                                         | `yarn build --print`                                     |
| List targets                                                                 | `yarn build --list targets`                              |
| Lint Dockerfile (BuildKit build checks, all targets)                         | `yarn build --check`                                     |
| Build every target for `linux/amd64` (no push; slow)                         | `yarn build`                                             |
| Build one target and load it into local Docker                               | `yarn build php-8-4-apache-dev --load`                   |
| Build for another platform                                                   | `PLATFORMS=linux/arm64 yarn build`                       |
| Format + lint JS, JSON and Markdown (check / fix)                            | `yarn biome check .` / `yarn biome check --write <file>` |
| Check `.tf` formatting                                                       | `tofu fmt -check -recursive`                             |

`bin/bake.js` always overwrites `PHP_VERSIONS` from `versions.json`, so setting it in the environment has no effect through `yarn build`.

## Workflow

- No CI runs on branches or PRs. Before committing a change to `build/`, `docker-bake.hcl` or `versions.json`, run `yarn build --print` and `yarn build --check`; for Dockerfile changes also build at least one affected target.
- Formatting: Biome (`@biomejs/biome`, pinned exactly in `devDependencies`) formats and lints `bin/**/*.js`, `*.json` and `*.md` with its recommended rules (`.cspell.json` is parsed as JSON with comments and trailing commas, via an override); `tofu fmt` formats `.tf`. After a Biome version bump, run `yarn biome migrate --write` so the `$schema` URL in `biome.json` matches. `docker-bake.hcl`, YAML, the Dockerfile, ini and conf files have no formatter: follow `.editorconfig` (2 spaces, 4 for `*.sh` and `Dockerfile*`, LF).
- Commit subjects are short, imperative and sentence case, with no conventional-commit prefix ("Switch from PECL to PIE").
- The Husky `prepare-commit-msg` hook prefixes the message with a Jira key from the branch name (`JA-123 Message`, project JA). If the branch has no key it prints "The JIRA ticket ID not found" and commits unchanged. That's fine.
- Renovate (`renovate.json`, shared `Jolt-Design/Renovate-Config`) opens PRs for Yarn, `@joltdesign/scripts`, GitHub Actions and lock file maintenance.
- Adding or removing a PHP version: edit `versions.json`, the `PHP_VERSIONS` default in `docker-bake.hcl` (used by raw `docker buildx bake`), any `dependency_versions` overrides, and the hardcoded loop in `buildspec.yml`. The `latest` tags move to the highest version automatically.

## Safety

- **Publishing needs explicit human approval every time.** `yarn push`, `docker buildx bake --push`, `yarn build:remote` (starts AWS CodeBuild) and `git push` to `master` all publish images or trigger a publish. The guard hook asks first.
- `yarn push` publishes only `PLATFORMS` (default `linux/amd64`), which replaces the multi-platform tags on Docker Hub. Prefer letting CI publish.
- Never print secrets: no `tofu output -json`/`-raw`, `tofu state pull`, `cat` of `*.tfstate*`/`.env*`, `aws ssm get-parameter --with-decryption`, `printenv`/`env`. Docker Hub credentials live in GitHub secrets and in AWS SSM under `/prod/sharedInfrastructure/dockerhub/`.
- `data.tf` declares no resources. Don't add any, and don't run `tofu apply`/`import`/`state` commands. The remote state belongs to the shared-infrastructure repo.

## Integrations

- **Docker Hub**: `joltdesign/php`. Publishing pipelines are described in `docs/publishing.md`.
- **GitHub Actions**: "Build and Push" (`.github/workflows/bake.yml`). It runs on push to `master` (paths above), weekly on Sunday 04:20 UTC, and manually. It builds each platform on a native runner, pushes by digest, then merges one manifest list per bake target.
- **AWS**: CodeBuild batch build (`buildspec.yml`, `buildspec-platform.yml`) is a legacy fallback, started with `yarn build:remote`. It pulls the base image through the ECR `docker-hub` pull-through cache. The project name comes from S3 remote state in `eu-west-1` via `data.tf`.
- **Jira**: project `JA` on joltdesign.atlassian.net (`.jira.d/config.yml`), used only for commit prefixes.

## Further docs

- `docs/publishing.md`: how images reach Docker Hub (GitHub Actions and the CodeBuild fallback).
