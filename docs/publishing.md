# Publishing images

All routes push to `joltdesign/php` on Docker Hub and overwrite existing tags. An agent must get explicit human approval before starting any of them.

## Live: GitHub Actions "Build and Push"

File: `.github/workflows/bake.yml`. This is the only enabled workflow.

Triggers:

- push to `master` that changes `.github/workflows/bake.yml`, `build/**`, `docker-bake.hcl` or `versions.json`
- schedule: Sundays at 04:20 UTC (rebuilds against the latest upstream `php` images)
- `workflow_dispatch`

What it does: logs in to Docker Hub (`vars.DOCKERHUB_USERNAME`, `secrets.DOCKERHUB_TOKEN`), sets up QEMU and Buildx, reads `versions.json` with `jq`, and runs `docker/bake-action` with `PLATFORMS=linux/amd64,linux/arm64` and `push: true`. A run takes about 1.5–2 hours because arm64 is emulated.

Check runs (read-only): `gh run list -w "Build and Push"`, `gh run view <id> --log-failed`.

## Disabled workflows

`bake-separate.yml` (build-separate-push) and `multi-platform-build.yml` (Multi-Platform Docker Build) build each platform on a native runner, push by digest, then merge manifests. Both are disabled in GitHub (`gh workflow list --all` shows `disabled_manually`). Known problems if they are re-enabled:

- `bake-separate.yml` "Inspect image" runs `jq` on `docker-bake.hcl`, which is HCL, not JSON, so the step fails.
- `multi-platform-build.yml` uses a runner label `ubuntu-latest-arm64`; `bake-separate.yml` uses `ubuntu-22.04-arm`.

## Legacy fallback: AWS CodeBuild

Started with `yarn build:remote`, which runs `jolt aws codebuild start --batch '{tf:codebuild_project_name}'`. `jolt` resolves the project name by running `tofu output -json` on the local state from `data.tf`, so `yarn prepare` (`tofu init` + `tofu refresh`) must have run with AWS credentials.

- `buildspec.yml` defines a batch: `amd64` and `arm64` builds (each using `buildspec-platform.yml`), then a `manifest` step that combines `<tag>-amd64` and `<tag>-arm64` with `docker manifest`.
- `buildspec-platform.yml` installs the latest Buildx, logs in to Docker Hub (credentials from SSM `/prod/sharedInfrastructure/dockerhub/*`) and ECR, and runs `docker buildx bake --push` with `BASE_IMAGE` pointed at the ECR `docker-hub` pull-through cache.
- The manifest step hardcodes the PHP versions (`for VERSION in "8.2" "8.3" "8.4" "8.5"`). It does not read `versions.json`.

## Local: `yarn push`

Runs `yarn build --push`. It builds only `PLATFORMS` (default `linux/amd64`), so the pushed tags replace the multi-platform manifests with single-platform images. Use it only when a human has decided to.
