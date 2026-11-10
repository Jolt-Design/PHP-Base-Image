# Jolt Docker PHP Base

Source repository for the [joltdesign/php][repo] image.

A modified version of the [PHP image][upstream] with extensions required by WordPress, useful default configurations, etc.

## Updating supported PHP Versions

1. Edit `versions.json` to add or remove PHP versions

The GitHub workflows and `yarn build` read this file automatically. The legacy CodeBuild manifest step in `buildspec.yml` has its own hardcoded version list, so update that too.

## Building

Run `yarn build` to test builds. Pushing to `master` (changes under `build/`, `docker-bake.hcl` or `versions.json`) publishes multi-platform images to the Docker Hub repo via the "Build and Push" GitHub workflow.

`yarn push` pushes from your machine, but only for `PLATFORMS` (default `linux/amd64`), so it replaces the multi-platform tags with single-platform ones.

Agent and contributor instructions: [AGENTS.md](AGENTS.md).

[repo]: https://hub.docker.com/r/joltdesign/php
[upstream]: https://hub.docker.com/_/php/
