# CyberPUNK Lab site workflow

This repository is the single source of truth for Han Wu's website:

`/Users/hanwu/Library/CloudStorage/OneDrive-UniversityofSouthampton/SOTON/CodeX_workspace/01_workspaces/WEBSITES/han_homepage`

Do not maintain a separate deployment folder such as `/tmp/han-homepage-*`. Do not commit or push unless Han explicitly asks for that operation. When GitHub already has the correct live site, avoid overwriting it automatically.

## Low-resource local preview template

Use this workflow when Codex is editing the lab website and the Mac feels slow, or when the Ruby/Jekyll environment is missing dependencies.

1. Edit source files in this repository first.
   - Lab CSS: `assets/lab/lab.css`
   - Lab layout: `_layouts/lab.html`
   - Lab data: `_data/lab/`
   - Lab pages: `lab/`

2. Prefer the full Jekyll server only when dependencies are already healthy:

   ```sh
   bundle exec jekyll serve --config _config.yml,_config.dev.yml --host 127.0.0.1 --port 4000 --no-watch
   ```

3. If Jekyll fails because a gem is missing, do not automatically run `bundle install`. Ask first. For a lightweight preview, serve the already-built `_site` folder instead:

   ```sh
   cd _site
   python3 -m http.server 4000 --bind 127.0.0.1
   ```

4. When using the static `_site` preview, remember that `_site` is generated preview output, not the authoritative source.
   - For CSS-only changes, mirror `assets/lab/lab.css` to `_site/assets/lab/lab.css` only so the running static preview updates.
   - For layout-only changes that must be previewed before rebuilding, mirror only the minimal rendered HTML snippet into `_site/lab/.../index.html`.
   - Keep the source files as the version Han should maintain.

5. Verify the preview with:

   ```sh
   curl -I http://127.0.0.1:4000/lab/
   ```

6. If the browser still shows old content, hard refresh the in-app browser. Static preview changes do not need a server restart if the served files changed.

## Performance rules

- Prefer static preview from `_site` when the machine is under load.
- Avoid looped visual effects unless Han explicitly asks for them.
- For UI animations, prefer `transform`, `opacity`, and short one-shot transitions.
- Respect `prefers-reduced-motion`.
- Do not make system-level changes while diagnosing performance.
- If port `4000` is occupied, inspect the process first; do not kill unrelated processes.

