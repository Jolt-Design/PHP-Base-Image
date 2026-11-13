# AGENTS.md

Source for the `joltdesign/php` Docker Hub image: the official `php` Apache image plus the extensions WordPress needs and Jolt's PHP/Apache config. It's built with Docker Buildx Bake. There's no application code and there are no tests; the only output is the published images.

## Where things are

- `versions.json`: the PHP versions to build. `yarn build`, GitHub Actions and the CodeBuild buildspecs read it.
- `docker-bake.hcl`: targets, tags, per-version `dependency_versions` overrides.
- `build/Dockerfile`: `production` stage, then `dev` (php.ini-development + Xdebug).
- `data.tf`: OpenTofu, read-only. It only reads the CodeBuild project name from the shared-infrastructure remote state.

## Commands

| Task                                                             | Command                                         |
| ---------------------------------------------------------------- | ----------------------------------------------- |
| Install deps                                                     | `yarn install`                                  |
| Full setup (Husky, `tofu init`/`refresh`; needs AWS credentials) | `yarn prepare`                                  |
| Show resolved bake config                                        | `yarn build --print`                            |
| Lint the Dockerfile (BuildKit checks)                            | `yarn build --check`                            |
| Build one target into local Docker                               | `yarn build php-8-4-apache-dev --load`          |
| Build for another platform                                       | `PLATFORMS=linux/arm64 yarn build …`            |
| Format and lint (Biome)                                          | `yarn lint` / `yarn biome check --write <file>` |
| Check `.tf` formatting                                           | `tofu fmt -check -recursive`                    |
| Lint GitHub Actions workflows                                    | `jactionlint`                                   |

- `bin/bake.js` always overwrites `PHP_VERSIONS` from `versions.json`, so setting it in the environment has no effect through `yarn build`.
- Yarn uses Plug'n'Play: run binaries installed by Yarn with `yarn <bin>`; there's no `node_modules/.bin`.

## Workflow

- No CI runs on branches or PRs. Before committing a change to `build/`, `docker-bake.hcl` or `versions.json`, run `yarn build --print` and `yarn build --check`. For Dockerfile changes, also build at least one affected target.
- Workflows under `.github/` must have no `jactionlint` findings (config: `.github/jactionlint.yaml`). Run `jactionlint` from the repo root after changing them.
- Biome covers whatever `biome.json` includes, and `tofu fmt` covers `.tf`. Everything else follows `.editorconfig`. After a Biome version bump, run `yarn biome migrate --write`.
- The Husky pre-commit hook runs `yarn lint --staged`. The `prepare-commit-msg` hook prefixes the Jira key from the branch name (project JA). On a branch without one it prints "The JIRA ticket ID not found", which is fine.
- Commit subjects are short, imperative and sentence case, with no conventional-commit prefix.
- To add or remove a PHP version, edit `versions.json`. If an extension doesn't build on a new version, add an entry for it to `dependency_versions` in `docker-bake.hcl`.

## Safety

- **Publishing needs explicit human approval every time.** `yarn push`, `docker buildx bake --push`, `yarn build:remote` (AWS CodeBuild) and `git push` to `master` all publish images. The guard hook asks first.
- `yarn push` publishes only `PLATFORMS` (default `linux/amd64`), replacing the multi-platform tags on Docker Hub. Prefer letting CI publish.
- Never print secrets: no `tofu output -json`/`-raw`, `tofu state pull`, `cat` of `*.tfstate*`/`.env*`, `aws ssm get-parameter --with-decryption`, `printenv`/`env`.
- `data.tf` declares no resources. Don't add any, and don't run `tofu apply`/`import`/`state`. The remote state belongs to the shared-infrastructure repo.

## Further docs

- `docs/publishing.md`: how images reach Docker Hub (GitHub Actions, the CodeBuild backup, `yarn push`).
