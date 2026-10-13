# Oichi original-approved production · 2026-10-13

Production ID: `oichi-original-approved-20261013`. The `v27` technical folder is retained for compatibility. This replaces the rejected earlier v27 art; the original adult face, body/head proportions, long high ponytail, white cropped jinbaori and red skirt are the sole approved design.

## Codex 交接入口（先讀這段）

新分支：`handoff/oichi-full-v27-20261012`。這份交接保留已測試的基底 `5f69da850aa44c97ea8f89b6aff85f7942433897`，包含完整可執行專案及阿市正式素材；直接從 Git 取得時，不需要另外覆蓋 ZIP。

交接時遠端 `main` 已前進到 `966cf8c3d48a4579554bc046a5961870faaaafa8`，先前 PR #1 已合併。此分支不回退、改写或合併 `main`。這次 8 組測試是在上述 `5f69da8` 基底執行，尚未驗證與新版 `main` 合併後的結果。

讓 Codex 接手時：

1. 先檢查並保留本機未提交的改動，`git fetch origin`，閱讀這份文件及草稿 PR 的差異。
2. 取得 `origin/handoff/oichi-full-v27-20261012`，確認 28 張正式 PNG 和 `registration.json`；不要重新生圖、套舊色盤或平均切割畫格。
3. 整合進目前遊戲時以差異／cherry-pick／PR 處理，勿把整個舊基底專案覆蓋到新版 `main`。保留友軍新增的劇情音效、頭目死亡動作、箭矢、圖鑑與離開存檔。
4. 特別檢查兩個交集：`game/render/frame_animation.gd` 的新版 `enemy_v14_sample` 頭目死亡時間處理應保留，並加入本分支 `hero_v22_sample` 的 `source_version`；`scripts/test-v19.mjs` 同一個測試清單位置需同時保留新版 `collection_progress_v26` 與本分支兩組 Oichi 測試，也保留新版 `--render-collection-v26`。
5. 整合後重跑下列檢查，再執行新版遊戲的回歸與 Windows／GUI 人工驗收。這個草稿 PR 不是合併後 CI 全通或正式發行驗收。

乾淨的新資料夾可檢視這個交接快照：

```sh
git clone --branch handoff/oichi-full-v27-20261012 https://github.com/guderian44444/sengoku-m1.git
cd sengoku-m1
```

Python 圖像檢查需 Python 3、Pillow、NumPy；原生檢查需 Node.js 和 Godot。Linux 範例中的 `GODOT_BIN` 請換成實際引擎路徑；Windows 可直接用 Godot 開啟 `game/project.godot`。第一次匯入的快取由 Godot 重建。

## Art and registration

- 26 canonical actions, six frames each: 156 registered frames, 155 unique drawings.
- `down/6` and `recovering/1` share the exact prone image, region, anatomical ruler, root and bow pose.
- 28 final RGBA sources. Run uses the top row of `run.png`, two figures in `run-opposite.png`, and the rightmost figure in `run-opposite-mixed.png`. Unused raw slots are provenance only. Registration is authoritative; do not auto-split uniform cells.
- Approved walk/low-sweep drawings are retained. Walk/run exchange near/far leg lead. Low-sweep frame3 retains its corrected free arm.
- Archery bodies are weapon-free. Existing bows, strings, arrows and effects remain separate. String-draw metadata is not used for guard/bash rigid grips.
- Action keys, aliases, timings, combat balance, 48 weapons, Nobunaga and Tadakatsu remain unchanged.

New regions and anchors are visually authored. Anatomical rulers follow skull/neck/pelvis and unfolded limb chains, not silhouette height. Down/recovery and selected combat poses have per-frame rulers. Estimates are generally 5–8% uncertain, not rigged-model precision.

## Deterministic brightness

The user approved texture and direct color adjustment. No color-only regeneration, repaint, warp, blur, denoise or flattening is used. Immutable native sources accompany the optional recipe archive. Only lightness is changed by monotone material curves with smooth color selection; dimensions, pixel coordinates and native alpha remain exact. Registration copies final graded PNGs byte-for-byte.

Inspected material ROIs exclude the portrait's brown background. Whole-image histograms are not calibration targets. All 28 final derivatives reproduce exactly from raw inputs and saved profiles. PNG, decoded RGBA, alpha, profile and implementation hashes are recorded.

| Material | Active-frame median L* range | Master median |
| --- | ---: | ---: |
| Skin | 77.36–77.74 | 77.55 |
| White cloth | 90.38–90.66 | 90.52 |
| Red skirt | 33.13–35.66 | 34.87 |

All skin/white/red median and highlight lightness checks meet unchanged limits. The audit covers 624 material/frame measurements with zero missing samples. **104 other flags remain**: 54 hair, 48 red chroma and 2 skin highlight-chroma. Individual dispositions are retained; this is not an all-color-thresholds pass. Hair is sometimes lighter than the portrait dark-hair ROI. Red saturation/texture variation is retained. Rotated launched poses also expose the top-of-figure hair proxy's limits.

Actual v19 Mori/Imagawa enemy pixels accompany the audit. These are comparators, not a demand for identical complexion or clothing material. The approved portrait remains the final target.

## Verification boundaries

Final command results and manifest hashes are in `docs/qa/oichi-v27/verification-summary.json`. Source/crop checks, grading replay, alpha identity, protected hashes, selected engine tests and all 16-bow geometry checks are separate evidence.

Available engine: Linux Godot 4.6.3. The separately documented Windows/Godot 4.7.2 platform is untested here. Native headless tests validate engine loading, metadata, state routing and layer contracts. They do not establish visual gameplay acceptance, physical controller feel, perfect contact for every alternate bow, or natural timing.

Overview/contact sheets and the 52-second montage are **offline asset composites, not gameplay captures**. Montage: two six-frame cycles per action at fixed review cadence, actual courtyard/enemy art. Body/bow margins are verified without clipping. Projectiles, hit timing and actor trajectories are not simulated.

Before release, use the existing capture script in a display-enabled build to inspect both facings, HUD likeness, floor placement, grip transitions, timing and action feel. No GUI viewport was available here.

## Install, reproduce, roll back

For ZIP delivery only, apply the three art packages and integration package together over baseline `5f69da850aa44c97ea8f89b6aff85f7942433897`, after backing up local edits. Recipe archive is optional for runtime but supplies complete raw inputs and implementation for exact grading replay; hashes alone are not that deliverable.

From repository root:

```sh
python3 scripts/register-oichi-v27.py --check
python3 scripts/test-oichi-v27.py
python3 scripts/test-oichi-colors-v27.py
GODOT_BIN=/usr/local/bin/godot node scripts/test-v19.mjs --only=oichi_pipeline_v27,oichi_layers_v27,hero_layers_v22,weapon_render_v22,projectile_v22,frame_animation,animation_timing_v11,weapon_expansion_v24
```

Historical Oichi assets remain intact. For reversible local fallback with the game closed, move `game/assets/v27/oichi/registration.json` out of its active filename. The resolver falls back to the historical v22 source route and its existing processing. Restore the manifest to re-enable this set; do not overwrite unrelated work.

Pre-existing candidate work and rejected runtime/QA were checkpointed before replacement. The QA files record pre-publication evidence; the branch commit and draft PR establish the published state. No merge or deployment is part of this handoff. Historical absolute paths in captured test logs identify the original run only and are not runtime dependencies.
