# Publishing images

All routes push to `joltdesign/php` on Docker Hub and overwrite existing tags. An agent must get explicit human approval before starting any of them.

## Live: GitHub Actions "Build and Push"

Triggers, runners and steps are in `.github/workflows/bake.yml`. What the file doesn't spell out:

- Each platform builds on its own native runner and pushes by digest only, so no per-architecture tags appear on Docker Hub.
- The `merge` job then gives each bake target its tags from `docker-bake.hcl`. A target's tags only move once every platform has built it; the job fails if a digest is missing.

Check runs (read-only): `gh run list -w "Build and Push"`, `gh run view <id> --log-failed`.

## Backup: AWS CodeBuild

Started with `yarn build:remote`. `jolt` resolves the CodeBuild project name from the local state of `data.tf`, so `yarn prepare` (`tofu init` + `tofu refresh`) must have run with AWS credentials. The build steps are in `buildspec.yml` and `buildspec-platform.yml`.

It doesn't read `versions.json` yet. It uses the `PHP_VERSIONS` default in `docker-bake.hcl` and a hardcoded loop in `buildspec.yml` (JA-33).

## Local: `yarn push`

Runs `yarn build --push`. It builds only `PLATFORMS` (default `linux/amd64`), so the pushed tags replace the multi-platform manifests with single-platform images. Use it only when a human has decided to.
