#!/usr/bin/env node
/**
 * Cross-platform wrapper for docker buildx bake that automatically reads
 * PHP versions from versions.json and passes them as environment variables.
 *
 * Usage: node bake.js [docker buildx bake arguments]
 * Example: node bake.js --print
 *          node bake.js --push
 */
const { execSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

// Read PHP versions from versions.json (single source of truth)
const versionsPath = path.join(__dirname, '..', 'versions.json');
const versions = JSON.parse(fs.readFileSync(versionsPath, 'utf8'));
const phpVersions = versions['php-versions'].join(',');

// Set environment variable and run docker buildx bake
const env = { ...process.env, PHP_VERSIONS: phpVersions };
const args = process.argv.slice(2);
const command = ['yarn', 'run', 'jolt', 'cmd', '{cmd:docker}', 'buildx', 'bake', ...args];

try {
  execSync(command.join(' '), {
    stdio: 'inherit',
    env: env
  });
} catch (error) {
  process.exit(error.status || 1);
}
