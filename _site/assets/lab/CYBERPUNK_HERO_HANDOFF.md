# CyberPUNK Lab 首屏交接

## 当前状态

- 已完成分层入场、鼠标/移动端视差、独立霓虹闪烁和 reduced-motion。
- 画布统一为 3840×2160。
- 灯牌位于实体建筑墙面；墙体和三组文字共用景深 `6`。
- 前景栏杆孔洞透明，人物和实体屋顶保留。
- Jekyll 构建、Lab 深链和首屏定向测试通过。

## 主要代码

- `_pages/lab/index.html`：图层顺序、路径、景深。
- `_layouts/lab.html`：底图预加载和动画脚本。
- `assets/lab/lab.css`：入场、布局、混合模式、reduced-motion。
- `assets/lab/lab-home-hero.js`：视差、移动端方向/触摸、霓虹闪烁、清理。
- `test/lab_site_test.rb`：Lab 页面测试。

## 实际使用素材

目录：`assets/lab/cyberpunk-lab-layered/`

1. `01_base_clean.png` — 干净城市底图，景深 4
2. `02_building_facade_clean.png` — 实体墙面和建筑框架，景深 6
3. `03_sign_cyber_clean.png` — Cyber，景深 6
4. `04_sign_punk_clean.png` — PUNK，景深 6
5. `05_sign_lab_clean.png` — Lab，景深 6
6. `06_drones_searchlights.png` — 无人机，景深 9，normal
7. `07_rain_fog_overlay.png` — 雨雾，景深 10，screen
8. `09_other_illuminated_signs_overlay.png` — 其他灯光，景深 8，screen
9. `08_foreground_rooftop_person_clean.png` — 人物、透明栏杆和屋顶，景深 12

原始说明：同目录的 `manifest.json`、`README.md`。素材包：`assets/lab/cyberpunk-lab-layered-assets-v2.zip`。

## 已知情况

全套测试有 4 个既有失败，涉及 publication、about header 和 opportunities 字号，与首屏动画无关。

## Mac mini 交接提示词

继续 CyberPUNK Lab 首屏工作。先阅读 `AGENTS.md` 和 `assets/lab/CYBERPUNK_HERO_HANDOFF.md`，检查现有实现后用 `./scripts/serve-local.sh` 启动并打开 `/lab/`。保留现有素材、图层顺序和动画逻辑，不要重新生成或覆盖图片；从当前状态继续修改并完成浏览器验证。
