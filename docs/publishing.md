# Publishing images

All routes push to `joltdesign/php` on Docker Hub and overwrite existing tags. An agent must get explicit human approval before starting any of them.

## Live: GitHub Actions "Build and Push"

File: `.github/workflows/bake.yml`.

Triggers:

- push to `master` that changes `.github/workflows/bake.yml`, `build/**`, `docker-bake.hcl` or `versions.json`
- schedule: Sundays at 04:20 UTC (rebuilds against the latest upstream `php` images)
- `workflow_dispatch`

What it does:

1. `build`: a matrix of two jobs, each on a native runner (`ubuntu-24.04` for `linux/amd64`, `ubuntu-24.04-arm` for `linux/arm64`; arm runners are free because the repo is public). Each job runs `docker/bake-action` for every target with `PLATFORMS` set to its own platform, clears the tags and pushes the images by digest only (`push-by-digest=true`), so no per-architecture tags appear on Docker Hub. It uploads the bake metadata (target name → digest) as an artifact.
2. `merge`: runs `docker buildx bake --print` to get each target's tags from `docker-bake.hcl` (including `latest`), then for each target runs `docker buildx imagetools create` with that target's tags and its digest from every platform. It fails if a target is missing a digest.

Each target's tags are updated only when both platforms have built.

Check runs (read-only): `gh run list -w "Build and Push"`, `gh run view <id> --log-failed`.

## Legacy fallback: AWS CodeBuild

Started with `yarn build:remote`, which runs `jolt aws codebuild start --batch '{tf:codebuild_project_name}'`. `jolt` resolves the project name by running `tofu output -json` on the local state from `data.tf`, so `yarn prepare` (`tofu init` + `tofu refresh`) must have run with AWS credentials.

- `buildspec.yml` defines a batch: `amd64` and `arm64` builds (each using `buildspec-platform.yml`), then a `manifest` step that combines `<tag>-amd64` and `<tag>-arm64` with `docker manifest`.
- `buildspec-platform.yml` installs the latest Buildx, logs in to Docker Hub (credentials from SSM `/prod/sharedInfrastructure/dockerhub/*`) and ECR, and runs `docker buildx bake --push` with `BASE_IMAGE` pointed at the ECR `docker-hub` pull-through cache.
- The manifest step hardcodes the PHP versions (`for VERSION in "8.2" "8.3" "8.4" "8.5"`). It does not read `versions.json`.

## Local: `yarn push`

Runs `yarn build --push`. It builds only `PLATFORMS` (default `linux/amd64`), so the pushed tags replace the multi-platform manifests with single-platform images. Use it only when a human has decided to.
