#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if command -v rbenv >/dev/null 2>&1; then
  run_ruby() { rbenv exec "$@"; }
else
  run_ruby() { "$@"; }
fi

if ! run_ruby bundle check >/dev/null 2>&1; then
  echo "Installing missing Ruby dependencies..."
  run_ruby bundle install
fi

echo "Starting the site at http://localhost:4000/"
if command -v rbenv >/dev/null 2>&1; then
  exec rbenv exec bundle exec jekyll serve --config _config.yml,_config.dev.yml -l "$@"
else
  exec bundle exec jekyll serve --config _config.yml,_config.dev.yml -l "$@"
fi
