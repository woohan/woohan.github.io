# Codex project instructions

## Local server

- When asked to start or run the local website, use `./scripts/serve-local.sh` from the repository root.
- Do not run a second server if port 4000 is already serving the site; verify the existing server instead.
- Keep the server process running and verify that `http://127.0.0.1:4000/` returns HTTP 200.
- The script selects the Ruby version from `.ruby-version`, installs gems only when they are missing, and enables LiveReload.
