# Codex project instructions

## Local server

- When asked to start or run the local website, use `./scripts/serve-local.sh` from the repository root.
- Do not run a second server if port 4000 is already serving the site; verify the existing server instead.
- Keep the server process running and verify that `http://127.0.0.1:4000/` returns HTTP 200.
- The script selects the Ruby version from `.ruby-version`, installs gems only when they are missing, and enables LiveReload.

## Lab content links

- Every item in `_data/lab/news.yml`, `_data/lab/publications.yml`, and `_data/lab/opportunities.yml`, plus every person in `_data/lab/team.yml`, must have a stable, unique, lowercase kebab-case `id`.
- Internal links from Lab home cards must deep-link to the exact target card or profile, using `#news-<id>`, `#publication-<id>`, `#person-<id>`, or `#opportunity-<id>`. Do not link an item card only to the top of its destination page.
- News items must define `home_url`. Prefer the most specific relevant target: a publication card for paper news, a person card for member news, or the news card itself otherwise.
- Page-level navigation such as “More” may link to the top of a destination page.
- Preserve existing IDs when editing titles or dates so inbound deep links remain stable.
- After changing Lab content or links, run `bundle exec ruby scripts/check_lab_deep_links.rb` against a current `_site` build.
