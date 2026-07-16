# CyberPUNK Lab layered background

- Original: `1586 x 992`
- Extended canvas: `3840 x 2160` (4K UHD)
- Original rendered at exact 2x: `3172 x 1984`
- Original offset on 4K canvas: `334, 88`
- All layer PNGs: full-canvas RGBA, aligned to the same origin
- Exact preview: `preview_extended_exact.png`
- Layer order and animation notes: `manifest.json`
- CSS starter: `animation.css`

Use absolutely positioned `<img>` elements in manifest order. Keep all images at the same rendered width/height; animate transforms and opacity only. The three title layers use original source pixels and preserve the exact strings `Cyber`, `PUNK`, and `Lab`.
