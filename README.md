# Jolt Docker PHP Base

Source repository for the [joltdesign/php](repo) image.

A modified version of the [PHP image](upstream) with extensions required by WordPress, useful default configurations, etc.

## Updating supported PHP Versions

1. Edit `versions.json` to add or remove PHP versions

All builds and workflows will automatically use the updated versions.

## Building

Run `yarn build` to test builds and `yarn push` to deploy them to the Docker Hub repo.

[repo]: https://hub.docker.com/r/joltdesign/php
[upstream]: https://hub.docker.com/_/php/
