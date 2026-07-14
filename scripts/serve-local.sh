#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if command -v rbenv >/dev/null 2>&1; then
  ruby_command=(rbenv exec)
else
  ruby_command=()
fi

if ! "${ruby_command[@]}" bundle check >/dev/null 2>&1; then
  echo "Installing missing Ruby dependencies..."
  "${ruby_command[@]}" bundle install
fi

echo "Starting the site at http://localhost:4000/"
exec "${ruby_command[@]}" bundle exec jekyll serve -l "$@"
